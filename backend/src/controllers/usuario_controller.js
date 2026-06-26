import Usuario from '../models/Usuario.js'
import Barrio from '../models/Barrio.js'
import { sendMailCredenciales } from '../helpers/sendMail.js'

const PASSWORD_INICIAL = 'Ecuador2026'

// ── CREAR COORDINADOR DE BRIGADA (lo crea el Coordinador de Campaña) ──────────
export const crearCoordinadorBrigada = async (req, res) => {
    try {
        const { nombre, apellido, cedula, email, telefono, barriosIds } = req.body

        // Validar campos obligatorios
        const faltantes = []
        if (!nombre)    faltantes.push('nombre')
        if (!apellido)  faltantes.push('apellido')
        if (!cedula)    faltantes.push('cedula')
        if (!email)     faltantes.push('email')
        if (!telefono)  faltantes.push('telefono')

        if (faltantes.length > 0) {
            return res.status(400).json({ msg: `Faltan campos: ${faltantes.join(', ')}` })
        }

        // Verificar duplicados
        const emailExiste  = await Usuario.findOne({ email: email.toLowerCase() })
        const cedulaExiste = await Usuario.findOne({ cedula })

        if (emailExiste)  return res.status(400).json({ msg: 'El correo ya está registrado' })
        if (cedulaExiste) return res.status(400).json({ msg: 'La cédula ya está registrada' })

        // Crear usuario
        const nuevoUsuario = new Usuario({
            nombre,
            apellido,
            cedula,
            email: email.toLowerCase(),
            telefono,
            rol: 'coordinador_brigada',
            creadoPor: req.usuarioBDD._id,
        })

        // Asignar barrios si se enviaron
        if (Array.isArray(barriosIds) && barriosIds.length > 0) {
            nuevoUsuario.barriosAsignados = barriosIds
        }

        nuevoUsuario.password = await nuevoUsuario.encryptPassword(PASSWORD_INICIAL)
        await nuevoUsuario.save()
        console.log('✅ Coordinador de Brigada creado:', nuevoUsuario._id)

        // Enviar credenciales por correo
        try {
            await sendMailCredenciales(email, `${nombre} ${apellido}`, 'coordinador_brigada', PASSWORD_INICIAL)
            console.log('📧 Credenciales enviadas a:', email)
        } catch (e) {
            console.error('⚠️ No se pudo enviar el correo:', e.message)
        }

        res.status(201).json({
            success: true,
            msg: 'Coordinador de Brigada creado exitosamente. Se enviaron las credenciales por correo.',
            data: {
                _id:               nuevoUsuario._id,
                nombre:            nuevoUsuario.nombre,
                apellido:          nuevoUsuario.apellido,
                cedula:            nuevoUsuario.cedula,
                email:             nuevoUsuario.email,
                telefono:          nuevoUsuario.telefono,
                rol:               nuevoUsuario.rol,
                barriosAsignados:  nuevoUsuario.barriosAsignados,
            },
        })

    } catch (error) {
        console.error('❌ Error al crear coordinador de brigada:', error.message)
        if (error.name === 'ValidationError') {
            const errores = Object.values(error.errors).map(e => e.message)
            return res.status(400).json({ msg: 'Error de validación', errors: errores })
        }
        res.status(500).json({ success: false, msg: 'Error interno del servidor', error: error.message })
    }
}

// ── CREAR VACUNADOR (lo crea el Coordinador de Brigada) ───────────────────────
export const crearVacunador = async (req, res) => {
    try {
        const { nombre, apellido, cedula, email, telefono, barrioId } = req.body

        // Validar campos obligatorios
        const faltantes = []
        if (!nombre)    faltantes.push('nombre')
        if (!apellido)  faltantes.push('apellido')
        if (!cedula)    faltantes.push('cedula')
        if (!email)     faltantes.push('email')
        if (!telefono)  faltantes.push('telefono')
        if (!barrioId)  faltantes.push('barrioId')

        if (faltantes.length > 0) {
            return res.status(400).json({ msg: `Faltan campos: ${faltantes.join(', ')}` })
        }

        // Verificar que el barrioId pertenezca a los barrios del coordinador
        const barriosDelCoordinador = req.usuarioBDD.barriosAsignados.map(b => b.toString())
        if (!barriosDelCoordinador.includes(barrioId.toString())) {
            return res.status(403).json({ msg: 'Solo puedes asignar vacunadores a barrios que administras.' })
        }

        // Verificar duplicados
        const emailExiste  = await Usuario.findOne({ email: email.toLowerCase() })
        const cedulaExiste = await Usuario.findOne({ cedula })

        if (emailExiste)  return res.status(400).json({ msg: 'El correo ya está registrado' })
        if (cedulaExiste) return res.status(400).json({ msg: 'La cédula ya está registrada' })

        // Crear usuario
        const nuevoUsuario = new Usuario({
            nombre,
            apellido,
            cedula,
            email: email.toLowerCase(),
            telefono,
            rol: 'vacunador',
            creadoPor: req.usuarioBDD._id,
            barriosAsignados: [barrioId],
        })

        nuevoUsuario.password = await nuevoUsuario.encryptPassword(PASSWORD_INICIAL)
        await nuevoUsuario.save()
        console.log('✅ Vacunador creado:', nuevoUsuario._id)

        // Enviar credenciales por correo
        try {
            await sendMailCredenciales(email, `${nombre} ${apellido}`, 'vacunador', PASSWORD_INICIAL)
            console.log('📧 Credenciales enviadas a:', email)
        } catch (e) {
            console.error('⚠️ No se pudo enviar el correo:', e.message)
        }

        res.status(201).json({
            success: true,
            msg: 'Vacunador creado exitosamente. Se enviaron las credenciales por correo.',
            data: {
                _id:              nuevoUsuario._id,
                nombre:           nuevoUsuario.nombre,
                apellido:         nuevoUsuario.apellido,
                cedula:           nuevoUsuario.cedula,
                email:            nuevoUsuario.email,
                telefono:         nuevoUsuario.telefono,
                rol:              nuevoUsuario.rol,
                barriosAsignados: nuevoUsuario.barriosAsignados,
            },
        })

    } catch (error) {
        console.error('❌ Error al crear vacunador:', error.message)
        if (error.name === 'ValidationError') {
            const errores = Object.values(error.errors).map(e => e.message)
            return res.status(400).json({ msg: 'Error de validación', errors: errores })
        }
        res.status(500).json({ success: false, msg: 'Error interno del servidor', error: error.message })
    }
}

// ── LISTAR USUARIOS CREADOS POR EL USUARIO AUTENTICADO ───────────────────────
export const listarMisUsuarios = async (req, res) => {
    try {
        const usuarios = await Usuario.find({ creadoPor: req.usuarioBDD._id })
            .select('-password')
            .populate('barriosAsignados', 'nombre sector')
            .lean()

        res.status(200).json({ success: true, total: usuarios.length, data: usuarios })

    } catch (error) {
        console.error('❌ Error al listar usuarios:', error.message)
        res.status(500).json({ success: false, msg: 'Error interno del servidor', error: error.message })
    }
}

// ── OBTENER USUARIO POR ID ────────────────────────────────────────────────────
export const obtenerUsuario = async (req, res) => {
    try {
        const { id } = req.params

        const usuario = await Usuario.findById(id)
            .select('-password')
            .populate('barriosAsignados', 'nombre sector')
            .populate('creadoPor', 'nombre apellido rol')
            .lean()

        if (!usuario) {
            return res.status(404).json({ msg: 'Usuario no encontrado' })
        }

        res.status(200).json({ success: true, data: usuario })

    } catch (error) {
        console.error('❌ Error al obtener usuario:', error.message)
        res.status(500).json({ success: false, msg: 'Error interno del servidor', error: error.message })
    }
}

// ── EDITAR USUARIO (nombre, apellido, teléfono) ───────────────────────────────
export const editarUsuario = async (req, res) => {
    try {
        const { id } = req.params
        const { nombre, apellido, telefono } = req.body

        const usuario = await Usuario.findById(id)
        if (!usuario) {
            return res.status(404).json({ msg: 'Usuario no encontrado' })
        }

        // Solo el creador o el coordinador_campana puede editar
        const esCreador = usuario.creadoPor?.toString() === req.usuarioBDD._id.toString()
        const esCampana = req.usuarioBDD.rol === 'coordinador_campana'

        if (!esCreador && !esCampana) {
            return res.status(403).json({ msg: 'No tienes permiso para editar este usuario' })
        }

        // Actualizar solo los campos permitidos que vengan en el body
        if (nombre)   usuario.nombre   = nombre.trim()
        if (apellido) usuario.apellido = apellido.trim()
        if (telefono) usuario.telefono = telefono.trim()

        await usuario.save()

        res.status(200).json({
            success: true,
            msg: 'Usuario actualizado correctamente',
            data: {
                _id:      usuario._id,
                nombre:   usuario.nombre,
                apellido: usuario.apellido,
                telefono: usuario.telefono,
                email:    usuario.email,
                cedula:   usuario.cedula,
                rol:      usuario.rol,
            },
        })

    } catch (error) {
        console.error('❌ Error al editar usuario:', error.message)
        if (error.name === 'ValidationError') {
            const errores = Object.values(error.errors).map(e => e.message)
            return res.status(400).json({ msg: 'Error de validación', errors: errores })
        }
        res.status(500).json({ success: false, msg: 'Error interno del servidor', error: error.message })
    }
}

// ── REASIGNAR BARRIO A VACUNADOR ──────────────────────────────────────────────
export const reasignarBarrioVacunador = async (req, res) => {
    try {
        const { id } = req.params
        const { barrioId } = req.body

        if (!barrioId) {
            return res.status(400).json({ msg: 'El campo barrioId es obligatorio' })
        }

        const usuario = await Usuario.findById(id)
        if (!usuario) {
            return res.status(404).json({ msg: 'Usuario no encontrado' })
        }

        // Solo aplica a vacunadores
        if (usuario.rol !== 'vacunador') {
            return res.status(400).json({ msg: 'Solo se puede reasignar barrio a un vacunador' })
        }

        // Solo el coordinador que creó al vacunador puede reasignarlo
        if (usuario.creadoPor?.toString() !== req.usuarioBDD._id.toString()) {
            return res.status(403).json({ msg: 'No tienes permiso para reasignar este vacunador' })
        }

        // El nuevo barrio debe estar dentro de los barrios que administra el coordinador
        const barriosDelCoordinador = req.usuarioBDD.barriosAsignados.map(b => b.toString())
        if (!barriosDelCoordinador.includes(barrioId.toString())) {
            return res.status(403).json({ msg: 'Solo puedes asignar vacunadores a barrios que administras.' })
        }

        // Reemplazar completamente el barrio (no agregar)
        usuario.barriosAsignados = [barrioId]
        await usuario.save()

        const usuarioActualizado = await Usuario.findById(id)
            .select('-password')
            .populate('barriosAsignados', 'nombre sector')
            .lean()

        res.status(200).json({
            success: true,
            msg: 'Barrio reasignado correctamente. Los registros de vacunación anteriores conservan su barrio original.',
            data: usuarioActualizado,
        })

    } catch (error) {
        console.error('❌ Error al reasignar barrio:', error.message)
        res.status(500).json({ success: false, msg: 'Error interno del servidor', error: error.message })
    }
}

// ── ACTUALIZAR BARRIOS DE UN COORDINADOR DE BRIGADA (solo coordinador_campana) ─
export const actualizarBarriosCoordinador = async (req, res) => {
    try {
        const { id } = req.params
        const { barriosIds } = req.body

        if (!Array.isArray(barriosIds)) {
            return res.status(400).json({ msg: 'barriosIds debe ser un array' })
        }

        const usuario = await Usuario.findById(id)
        if (!usuario) {
            return res.status(404).json({ msg: 'Usuario no encontrado' })
        }

        if (usuario.rol !== 'coordinador_brigada') {
            return res.status(400).json({ msg: 'Solo se pueden editar barrios de un coordinador de brigada' })
        }

        // Limpiar coordinadorAsignado en barrios que se quitan
        const barriosAnteriores = usuario.barriosAsignados.map(b => b.toString())
        const barriosNuevos     = barriosIds.map(b => b.toString())
        const barriosQuitados   = barriosAnteriores.filter(b => !barriosNuevos.includes(b))
        const barriosAgregados  = barriosNuevos.filter(b => !barriosAnteriores.includes(b))

        if (barriosQuitados.length > 0) {
            await Barrio.updateMany(
                { _id: { $in: barriosQuitados }, coordinadorAsignado: id },
                { $set: { coordinadorAsignado: null } }
            )
        }

        if (barriosAgregados.length > 0) {
            await Barrio.updateMany(
                { _id: { $in: barriosAgregados } },
                { $set: { coordinadorAsignado: id } }
            )
        }

        usuario.barriosAsignados = barriosIds
        await usuario.save()

        const actualizado = await Usuario.findById(id)
            .select('-password')
            .populate('barriosAsignados', 'nombre sector')
            .lean()

        res.status(200).json({
            success: true,
            msg: 'Barrios actualizados correctamente',
            data: actualizado,
        })

    } catch (error) {
        console.error('❌ Error al actualizar barrios:', error.message)
        res.status(500).json({ success: false, msg: 'Error interno del servidor', error: error.message })
    }
}


export const desactivarUsuario = async (req, res) => {
    try {
        const { id } = req.params

        const usuario = await Usuario.findById(id).select('+estado')
        if (!usuario) {
            return res.status(404).json({ msg: 'Usuario no encontrado' })
        }

        // Solo el creador o el coordinador_campana puede desactivar
        const esCreador = usuario.creadoPor?.toString() === req.usuarioBDD._id.toString()
        const esCampana = req.usuarioBDD.rol === 'coordinador_campana'

        if (!esCreador && !esCampana) {
            return res.status(403).json({ msg: 'No tienes permiso para desactivar este usuario' })
        }

        usuario.estado = 'inactivo'
        await usuario.save()

        res.status(200).json({ success: true, msg: 'Usuario desactivado correctamente' })

    } catch (error) {
        console.error('❌ Error al desactivar usuario:', error.message)
        res.status(500).json({ success: false, msg: 'Error interno del servidor', error: error.message })
    }
}
