import Vacunacion from '../models/Vacunacion.js'
import Usuario from '../models/Usuario.js'
import { eliminarImagenCloudinary, subirImagenBuffer } from '../config/cloudinary.js'

// ── HELPER: permiso para editar/eliminar un registro de vacunación ───────────
// - El vacunador que creó el registro siempre puede editarlo/eliminarlo.
// - El coordinador_brigada que CREÓ a ese vacunador también puede
//   editar/corregir sus registros (no eliminar, salvo que se indique).
const puedeModificarVacunacion = async (usuarioBDD, vacunacion) => {
    // Caso 1: el propio vacunador, dueño del registro
    if (usuarioBDD.rol === 'vacunador') {
        return vacunacion.vacunador.toString() === usuarioBDD._id.toString()
    }

    // Caso 2: coordinador_brigada que creó al vacunador dueño del registro
    if (usuarioBDD.rol === 'coordinador_brigada') {
        const vacunador = await Usuario.findById(vacunacion.vacunador).select('creadoPor')
        if (!vacunador || !vacunador.creadoPor) return false
        return vacunador.creadoPor.toString() === usuarioBDD._id.toString()
    }

    return false
}

// ── HELPER: obtener IDs de todos los vacunadores bajo un coordinador_campana ──
const vacunadoresDeCampana = async (campanaId) => {
    const brigadas = await Usuario.find({ creadoPor: campanaId, rol: 'coordinador_brigada' }).select('_id')
    const vacunadores = await Usuario.find({
        creadoPor: { $in: brigadas.map(b => b._id) },
        rol: 'vacunador',
    }).select('_id')
    return vacunadores.map(v => v._id)
}

// ── CREAR VACUNACIÓN ──────────────────────────────────────────────────────────
export const crearVacunacion = async (req, res) => {
    try {
        const {
            propietarioNombre, propietarioCedula, propietarioTelefono,
            mascotaTipo, mascotaNombre, mascotaEdad, mascotaSexo,
            vacuna, observaciones,
            latitud, longitud,
            clienteId,
            fechaRegistro,
        } = req.body

        if (!req.file) {
            return res.status(400).json({ msg: 'La fotografía de la mascota es obligatoria' })
        }

        let imagenUpload
        try {
            imagenUpload = await subirImagenBuffer(req.file.buffer)
        } catch (uploadError) {
            return res.status(500).json({ msg: 'Error al subir la imagen. Intenta de nuevo.' })
        }

        if (clienteId) {
            const existente = await Vacunacion.findOne({ clienteId })
            if (existente) {
                await eliminarImagenCloudinary(imagenUpload.public_id)
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

        const vacunadorDB = await Usuario.findById(req.usuarioBDD._id).populate('barriosAsignados')

        if (!vacunadorDB.barriosAsignados || vacunadorDB.barriosAsignados.length === 0) {
            return res.status(400).json({ msg: 'No tienes barrios asignados. Contacta a tu coordinador.' })
        }

        // El barrioId que mande el cliente solo se respeta si realmente
        // pertenece a los barrios asignados del vacunador. Si no, o si no
        // se mandó ninguno, se usa su barrio por defecto. Esto evita que
        // alguien con el token de un vacunador fuerce un barrioId ajeno
        // (p. ej. llamando directo a la API).
        const barriosVacunadorIds = vacunadorDB.barriosAsignados.map(b => b._id.toString())
        const barrioId = (req.body.barrioId && barriosVacunadorIds.includes(req.body.barrioId))
            ? req.body.barrioId
            : vacunadorDB.barriosAsignados[0]._id
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
            imagenUrl:      imagenUpload.secure_url,
            imagenPublicId: imagenUpload.public_id,
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
        if (imagenUpload?.public_id) {
            await eliminarImagenCloudinary(imagenUpload.public_id)
        }
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
            // Solo sus propios registros
            filtro.vacunador = _id
        } else if (rol === 'coordinador_brigada') {
            // Solo los vacunadores que él creó
            const vacunadores = await Usuario.find({ creadoPor: _id, rol: 'vacunador' }).select('_id')
            filtro.vacunador = { $in: vacunadores.map(v => v._id) }
        } else if (rol === 'coordinador_campana') {
            // Solo los vacunadores de sus coordinadores de brigada
            const ids = await vacunadoresDeCampana(_id)
            filtro.vacunador = { $in: ids }
        }

        const vacunaciones = await Vacunacion.find(filtro)
            .populate('vacunador', 'nombre apellido cedula')
            .populate('barrio', 'nombre sector')
            .sort({ fechaRegistro: -1 })

        res.status(200).json({ success: true, total: vacunaciones.length, vacunaciones })

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

        const { rol, _id } = req.usuarioBDD

        if (rol === 'vacunador') {
            if (vacunacion.vacunador._id.toString() !== _id.toString()) {
                return res.status(403).json({ msg: 'No tienes permiso para ver este registro' })
            }
        } else if (rol === 'coordinador_brigada') {
            const vacunadores = await Usuario.find({ creadoPor: _id, rol: 'vacunador' }).select('_id')
            const ids = vacunadores.map(v => v._id.toString())
            if (!ids.includes(vacunacion.vacunador._id.toString())) {
                return res.status(403).json({ msg: 'No tienes permiso para ver este registro' })
            }
        } else if (rol === 'coordinador_campana') {
            const ids = (await vacunadoresDeCampana(_id)).map(v => v.toString())
            if (!ids.includes(vacunacion.vacunador._id.toString())) {
                return res.status(403).json({ msg: 'No tienes permiso para ver este registro' })
            }
        }

        res.status(200).json({ success: true, vacunacion })

    } catch (error) {
        console.error('❌ Error al obtener vacunación:', error.message)
        res.status(500).json({ success: false, msg: 'Error interno del servidor', error: error.message })
    }
}

// ── EDITAR VACUNACIÓN (vacunador dueño, o su coordinador de brigada) ─────────
export const editarVacunacion = async (req, res) => {
    try {
        const { id } = req.params
        const vacunacion = await Vacunacion.findById(id)

        if (!vacunacion) {
            return res.status(404).json({ msg: 'Vacunación no encontrada' })
        }

        if (!(await puedeModificarVacunacion(req.usuarioBDD, vacunacion))) {
            return res.status(403).json({ msg: 'No tienes permiso para editar esta vacunación.' })
        }

        const {
            propietarioNombre, propietarioCedula, propietarioTelefono,
            mascotaTipo, mascotaNombre, mascotaEdad, mascotaSexo,
            vacuna, observaciones, latitud, longitud,
        } = req.body

        if (propietarioNombre)   vacunacion.propietario.nombre   = propietarioNombre
        if (propietarioCedula)   vacunacion.propietario.cedula   = propietarioCedula
        if (propietarioTelefono) vacunacion.propietario.telefono = propietarioTelefono
        if (mascotaTipo)         vacunacion.mascota.tipo         = mascotaTipo
        if (mascotaNombre)       vacunacion.mascota.nombre       = mascotaNombre
        if (mascotaEdad)         vacunacion.mascota.edad         = Number(mascotaEdad)
        if (mascotaSexo)         vacunacion.mascota.sexo         = mascotaSexo
        if (vacuna)              vacunacion.vacuna               = vacuna
        if (observaciones !== undefined) vacunacion.observaciones = observaciones
        if (latitud  !== undefined) vacunacion.ubicacion.latitud  = Number(latitud)
        if (longitud !== undefined) vacunacion.ubicacion.longitud = Number(longitud)

        if (req.file) {
            const nuevaImagen = await subirImagenBuffer(req.file.buffer)
            await eliminarImagenCloudinary(vacunacion.imagenPublicId)
            vacunacion.imagenUrl      = nuevaImagen.secure_url
            vacunacion.imagenPublicId = nuevaImagen.public_id
        }

        await vacunacion.save()
        await vacunacion.populate([
            { path: 'vacunador', select: 'nombre apellido' },
            { path: 'barrio',   select: 'nombre sector' },
        ])

        res.status(200).json({ success: true, msg: 'Vacunación actualizada correctamente', vacunacion })

    } catch (error) {
        console.error('❌ Error al editar vacunación:', error.message)
        res.status(500).json({ success: false, msg: 'Error interno del servidor', error: error.message })
    }
}

// ── ELIMINAR VACUNACIÓN (solo el vacunador que la creó) ───────────────────────
export const eliminarVacunacion = async (req, res) => {
    try {
        const { id } = req.params
        const vacunacion = await Vacunacion.findById(id)

        if (!vacunacion) {
            return res.status(200).json({ success: true, msg: 'La vacunación ya había sido eliminada', yaEliminado: true })
        }

        const esVacunadorDueno =
            req.usuarioBDD.rol === 'vacunador' &&
            vacunacion.vacunador.toString() === req.usuarioBDD._id.toString()

        if (!esVacunadorDueno) {
            return res.status(403).json({ msg: 'Solo el vacunador que registró esta vacunación puede eliminarla.' })
        }

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
            const vacunadores = await Usuario.find({ creadoPor: _id, rol: 'vacunador' }).select('_id')
            matchStage = { vacunador: { $in: vacunadores.map(v => v._id) } }
        } else if (rol === 'coordinador_campana') {
            const ids = await vacunadoresDeCampana(_id)
            matchStage = { vacunador: { $in: ids } }
        }

        const [totalResult, porTipo, porBarrio, porVacunador] = await Promise.all([
            Vacunacion.countDocuments(matchStage),
            Vacunacion.aggregate([
                { $match: matchStage },
                { $group: { _id: '$mascota.tipo', total: { $sum: 1 } } },
            ]),
            Vacunacion.aggregate([
                { $match: matchStage },
                { $lookup: { from: 'barrios', localField: 'barrio', foreignField: '_id', as: 'barrioInfo' } },
                { $unwind: '$barrioInfo' },
                { $group: { _id: '$barrioInfo.nombre', sector: { $first: '$barrioInfo.sector' }, total: { $sum: 1 } } },
                { $sort: { total: -1 } },
            ]),
            Vacunacion.aggregate([
                { $match: matchStage },
                { $lookup: { from: 'usuarios', localField: 'vacunador', foreignField: '_id', as: 'vacunadorInfo' } },
                { $unwind: '$vacunadorInfo' },
                {
                    $group: {
                        _id:      '$vacunadorInfo._id',
                        nombre:   { $first: '$vacunadorInfo.nombre' },
                        apellido: { $first: '$vacunadorInfo.apellido' },
                        total:    { $sum: 1 },
                        perros:   { $sum: { $cond: [{ $eq: ['$mascota.tipo', 'perro'] }, 1, 0] } },
                        gatos:    { $sum: { $cond: [{ $eq: ['$mascota.tipo', 'gato'] }, 1, 0] } },
                    },
                },
                { $sort: { total: -1 } },
            ]),
        ])

        const perros = porTipo.find(t => t._id === 'perro')?.total || 0
        const gatos  = porTipo.find(t => t._id === 'gato')?.total  || 0

        res.status(200).json({
            success: true,
            estadisticas: { total: totalResult, perros, gatos, porBarrio, porVacunador },
        })

    } catch (error) {
        console.error('❌ Error en estadísticas:', error.message)
        res.status(500).json({ success: false, msg: 'Error interno del servidor', error: error.message })
    }
}
