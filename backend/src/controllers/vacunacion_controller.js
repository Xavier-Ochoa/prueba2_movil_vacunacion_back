import Vacunacion from '../models/Vacunacion.js'
import Usuario from '../models/Usuario.js'
import { eliminarImagenCloudinary } from '../config/cloudinary.js'

// ── HELPER: ¿puede este usuario corregir este registro? ───────────────────────
// Devuelve true si:
//   - Es el vacunador que creó el registro, O
//   - Es el coordinador de brigada del barrio guardado en el registro
const puedeCorregirRegistro = (usuarioBDD, vacunacion) => {
    if (usuarioBDD.rol === 'vacunador') {
        return vacunacion.vacunador.toString() === usuarioBDD._id.toString()
    }
    if (usuarioBDD.rol === 'coordinador_brigada') {
        const barriosDelCoordinador = (usuarioBDD.barriosAsignados || []).map(b => b.toString())
        return barriosDelCoordinador.includes(vacunacion.barrio.toString())
    }
    return false
}

// ── CREAR VACUNACIÓN ──────────────────────────────────────────────────────────
export const crearVacunacion = async (req, res) => {
    try {
        const {
            propietarioNombre, propietarioCedula, propietarioTelefono,
            mascotaTipo, mascotaNombre, mascotaEdad, mascotaSexo,
            vacuna, observaciones,
            latitud, longitud,
            clienteId,       // id generado en el dispositivo (Sprint 3 - offline)
            fechaRegistro,   // fecha real en que se vacunó, capturada en el celular
        } = req.body

        // La imagen es obligatoria
        if (!req.file) {
            return res.status(400).json({ msg: 'La fotografía de la mascota es obligatoria' })
        }

        // ── Idempotencia: si este registro ya llegó antes (reintento de  ──
        // ── sincronización tras un corte de red o respuesta perdida),    ──
        // ── no lo insertamos de nuevo y devolvemos el ya existente.       ──
        if (clienteId) {
            const existente = await Vacunacion.findOne({ clienteId })
            if (existente) {
                // Como el registro ya existe, la nueva imagen subida en este
                // reintento es redundante: la eliminamos para no dejar basura.
                await eliminarImagenCloudinary(req.file.filename)

                await existente.populate([
                    { path: 'vacunador', select: 'nombre apellido' },
                    { path: 'barrio',   select: 'nombre sector' },
                ])
                return res.status(200).json({
                    success: true,
                    msg: 'Vacunación ya estaba sincronizada',
                    duplicado: true,
                    vacunacion: existente,
                })
            }
        }

        // El vacunador debe tener barrio asignado
        const vacunadorDB = await Usuario.findById(req.usuarioBDD._id)
            .populate('barriosAsignados')

        if (!vacunadorDB.barriosAsignados || vacunadorDB.barriosAsignados.length === 0) {
            return res.status(400).json({ msg: 'No tienes barrios asignados. Contacta a tu coordinador.' })
        }

        // Tomar el primer barrio asignado (o el que envíe el frontend)
        const barrioId = req.body.barrioId || vacunadorDB.barriosAsignados[0]._id

        // Fecha real de vacunación: la que vino del dispositivo (puede ser
        // de hace varios días si se registró sin señal). Si no llega,
        // usamos el momento actual como respaldo.
        const fechaRegistroReal = fechaRegistro ? new Date(fechaRegistro) : new Date()

        const nuevaVacunacion = new Vacunacion({
            propietario: {
                nombre:   propietarioNombre,
                cedula:   propietarioCedula,
                telefono: propietarioTelefono,
            },
            mascota: {
                tipo:   mascotaTipo,
                nombre: mascotaNombre,
                edad:   Number(mascotaEdad),
                sexo:   mascotaSexo,
            },
            vacuna,
            observaciones,
            imagenUrl:      req.file.path,
            imagenPublicId: req.file.filename,
            ubicacion: {
                latitud:  latitud  ? Number(latitud)  : null,
                longitud: longitud ? Number(longitud) : null,
            },
            vacunador:           req.usuarioBDD._id,
            barrio:               barrioId,
            fechaRegistro:        fechaRegistroReal,
            fechaSincronizacion:  new Date(),
            clienteId:            clienteId || undefined,
        })

        await nuevaVacunacion.save()
        await nuevaVacunacion.populate([
            { path: 'vacunador', select: 'nombre apellido' },
            { path: 'barrio',   select: 'nombre sector' },
        ])

        res.status(201).json({
            success: true,
            msg: 'Vacunación registrada correctamente',
            vacunacion: nuevaVacunacion,
        })

    } catch (error) {
        // Si la imagen ya se subió pero el registro falla, eliminarla
        if (req.file?.filename) {
            await eliminarImagenCloudinary(req.file.filename)
        }

        // Carrera entre reintentos simultáneos: el índice unique de
        // clienteId puede rechazar el segundo insert justo después de
        // que el primero pasó el chequeo de arriba. Lo tratamos igual
        // que un duplicado en vez de un error 500.
        if (error.code === 11000 && error.keyPattern?.clienteId) {
            const existente = await Vacunacion.findOne({ clienteId: req.body.clienteId })
                .populate([
                    { path: 'vacunador', select: 'nombre apellido' },
                    { path: 'barrio',   select: 'nombre sector' },
                ])
            return res.status(200).json({
                success: true,
                msg: 'Vacunación ya estaba sincronizada',
                duplicado: true,
                vacunacion: existente,
            })
        }

        console.error('❌ Error al crear vacunación:', error.message)
        res.status(500).json({ success: false, msg: 'Error interno del servidor', error: error.message })
    }
}

// ── LISTAR VACUNACIONES ───────────────────────────────────────────────────────
export const listarVacunaciones = async (req, res) => {
    try {
        const { rol, _id } = req.usuarioBDD
        let filtro = {}

        if (rol === 'vacunador') {
            // Solo ve sus propios registros
            filtro.vacunador = _id
        } else if (rol === 'coordinador_brigada') {
            // Ve los registros de sus vacunadores
            const vacunadores = await Usuario.find({ creadoPor: _id }).select('_id')
            const idsVacunadores = vacunadores.map(v => v._id)
            filtro.vacunador = { $in: idsVacunadores }
        }
        // coordinador_campana → ve todo (filtro vacío)

        const vacunaciones = await Vacunacion.find(filtro)
            .populate('vacunador', 'nombre apellido cedula')
            .populate('barrio', 'nombre sector')
            .sort({ fechaRegistro: -1 })

        res.status(200).json({
            success: true,
            total: vacunaciones.length,
            vacunaciones,
        })

    } catch (error) {
        console.error('❌ Error al listar vacunaciones:', error.message)
        res.status(500).json({ success: false, msg: 'Error interno del servidor', error: error.message })
    }
}

// ── OBTENER UNA VACUNACIÓN ────────────────────────────────────────────────────
export const obtenerVacunacion = async (req, res) => {
    try {
        const { id } = req.params
        const vacunacion = await Vacunacion.findById(id)
            .populate('vacunador', 'nombre apellido cedula')
            .populate('barrio', 'nombre sector')

        if (!vacunacion) {
            return res.status(404).json({ msg: 'Vacunación no encontrada' })
        }

        // Verificar acceso
        const { rol, _id } = req.usuarioBDD
        if (rol === 'vacunador' && vacunacion.vacunador._id.toString() !== _id.toString()) {
            return res.status(403).json({ msg: 'No tienes permiso para ver este registro' })
        }

        res.status(200).json({ success: true, vacunacion })

    } catch (error) {
        console.error('❌ Error al obtener vacunación:', error.message)
        res.status(500).json({ success: false, msg: 'Error interno del servidor', error: error.message })
    }
}

// ── EDITAR VACUNACIÓN ─────────────────────────────────────────────────────────
export const editarVacunacion = async (req, res) => {
    try {
        const { id } = req.params
        const vacunacion = await Vacunacion.findById(id)

        if (!vacunacion) {
            return res.status(404).json({ msg: 'Vacunación no encontrada' })
        }

        // Verificar permiso: creador o coordinador del barrio del registro
        if (!puedeCorregirRegistro(req.usuarioBDD, vacunacion)) {
            return res.status(403).json({
                msg: 'No tienes permiso para editar este registro. Debes ser el vacunador que lo creó o el coordinador de brigada del barrio al que pertenece.',
            })
        }

        const {
            propietarioNombre, propietarioCedula, propietarioTelefono,
            mascotaTipo, mascotaNombre, mascotaEdad, mascotaSexo,
            vacuna, observaciones, latitud, longitud,
        } = req.body

        // Actualizar campos del propietario
        if (propietarioNombre)   vacunacion.propietario.nombre   = propietarioNombre
        if (propietarioCedula)   vacunacion.propietario.cedula   = propietarioCedula
        if (propietarioTelefono) vacunacion.propietario.telefono = propietarioTelefono

        // Actualizar campos de la mascota
        if (mascotaTipo)   vacunacion.mascota.tipo   = mascotaTipo
        if (mascotaNombre) vacunacion.mascota.nombre = mascotaNombre
        if (mascotaEdad)   vacunacion.mascota.edad   = Number(mascotaEdad)
        if (mascotaSexo)   vacunacion.mascota.sexo   = mascotaSexo

        if (vacuna)        vacunacion.vacuna        = vacuna
        if (observaciones !== undefined) vacunacion.observaciones = observaciones

        // Actualizar GPS si se envía
        if (latitud  !== undefined) vacunacion.ubicacion.latitud  = Number(latitud)
        if (longitud !== undefined) vacunacion.ubicacion.longitud = Number(longitud)

        // Actualizar imagen si se envía una nueva
        if (req.file) {
            await eliminarImagenCloudinary(vacunacion.imagenPublicId)
            vacunacion.imagenUrl      = req.file.path
            vacunacion.imagenPublicId = req.file.filename
        }

        await vacunacion.save()
        await vacunacion.populate([
            { path: 'vacunador', select: 'nombre apellido' },
            { path: 'barrio',   select: 'nombre sector' },
        ])

        res.status(200).json({
            success: true,
            msg: 'Vacunación actualizada correctamente',
            vacunacion,
        })

    } catch (error) {
        if (req.file?.filename) {
            await eliminarImagenCloudinary(req.file.filename)
        }
        console.error('❌ Error al editar vacunación:', error.message)
        res.status(500).json({ success: false, msg: 'Error interno del servidor', error: error.message })
    }
}

// ── ELIMINAR VACUNACIÓN ───────────────────────────────────────────────────────
export const eliminarVacunacion = async (req, res) => {
    try {
        const { id } = req.params
        const vacunacion = await Vacunacion.findById(id)

        if (!vacunacion) {
            // Idempotencia: si la app reintenta un DELETE que ya se
            // procesó antes (p. ej. perdió la respuesta por un corte de
            // señal), el resultado deseado ("que no exista") ya se cumple.
            return res.status(200).json({
                success: true,
                msg: 'La vacunación ya había sido eliminada',
                yaEliminado: true,
            })
        }

        // Verificar permiso: creador o coordinador del barrio del registro
        if (!puedeCorregirRegistro(req.usuarioBDD, vacunacion)) {
            return res.status(403).json({
                msg: 'No tienes permiso para eliminar este registro. Debes ser el vacunador que lo creó o el coordinador de brigada del barrio al que pertenece.',
            })
        }

        // Eliminar imagen de Cloudinary
        await eliminarImagenCloudinary(vacunacion.imagenPublicId)

        await Vacunacion.findByIdAndDelete(id)

        res.status(200).json({ success: true, msg: 'Vacunación eliminada correctamente' })

    } catch (error) {
        console.error('❌ Error al eliminar vacunación:', error.message)
        res.status(500).json({ success: false, msg: 'Error interno del servidor', error: error.message })
    }
}

// ── DASHBOARD / ESTADÍSTICAS ──────────────────────────────────────────────────
export const obtenerEstadisticas = async (req, res) => {
    try {
        const { rol, _id } = req.usuarioBDD
        let matchStage = {}

        if (rol === 'vacunador') {
            matchStage = { vacunador: _id }
        } else if (rol === 'coordinador_brigada') {
            const vacunadores = await Usuario.find({ creadoPor: _id }).select('_id')
            matchStage = { vacunador: { $in: vacunadores.map(v => v._id) } }
        }
        // coordinador_campana → ve todo (matchStage vacío)

        const [totalResult, porTipo, porBarrio, porVacunador] = await Promise.all([
            // Total vacunaciones
            Vacunacion.countDocuments(matchStage),

            // Por tipo de mascota
            Vacunacion.aggregate([
                { $match: matchStage },
                { $group: { _id: '$mascota.tipo', total: { $sum: 1 } } },
            ]),

            // Por barrio
            Vacunacion.aggregate([
                { $match: matchStage },
                {
                    $lookup: {
                        from: 'barrios',
                        localField: 'barrio',
                        foreignField: '_id',
                        as: 'barrioInfo',
                    },
                },
                { $unwind: '$barrioInfo' },
                {
                    $group: {
                        _id:    '$barrioInfo.nombre',
                        sector: { $first: '$barrioInfo.sector' },
                        total:  { $sum: 1 },
                    },
                },
                { $sort: { total: -1 } },
            ]),

            // Por vacunador (relevante para coordinadores; un vacunador
            // viendo su propio dashboard solo se verá a sí mismo)
            Vacunacion.aggregate([
                { $match: matchStage },
                {
                    $lookup: {
                        from: 'usuarios',
                        localField: 'vacunador',
                        foreignField: '_id',
                        as: 'vacunadorInfo',
                    },
                },
                { $unwind: '$vacunadorInfo' },
                {
                    $group: {
                        _id:     '$vacunadorInfo._id',
                        nombre:  { $first: '$vacunadorInfo.nombre' },
                        apellido:{ $first: '$vacunadorInfo.apellido' },
                        total:   { $sum: 1 },
                        perros:  { $sum: { $cond: [{ $eq: ['$mascota.tipo', 'perro'] }, 1, 0] } },
                        gatos:   { $sum: { $cond: [{ $eq: ['$mascota.tipo', 'gato'] }, 1, 0] } },
                    },
                },
                { $sort: { total: -1 } },
            ]),
        ])

        const perros = porTipo.find(t => t._id === 'perro')?.total || 0
        const gatos  = porTipo.find(t => t._id === 'gato')?.total  || 0

        res.status(200).json({
            success: true,
            estadisticas: {
                total: totalResult,
                perros,
                gatos,
                porBarrio,
                porVacunador,
            },
        })

    } catch (error) {
        console.error('❌ Error en estadísticas:', error.message)
        res.status(500).json({ success: false, msg: 'Error interno del servidor', error: error.message })
    }
}
