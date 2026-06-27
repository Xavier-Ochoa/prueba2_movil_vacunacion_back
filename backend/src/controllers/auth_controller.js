import Usuario from '../models/Usuario.js'
import TokenBlacklist from '../models/TokenBlacklist.js'
import { crearTokenJWT, obtenerExpiracionToken } from '../middlewares/JWT.js'
import { sendMailRecuperarPassword, sendMailPasswordCambiada } from '../helpers/sendMail.js'

// ── LOGIN ─────────────────────────────────────────────────────────────────────
export const login = async (req, res) => {
    try {
        const { email, password } = req.body

        if (!email || !password) {
            return res.status(400).json({ msg: 'Debes proporcionar correo y contraseña' })
        }

        const usuarioBDD = await Usuario.findOne({ email: email.toLowerCase() })
            .select('+estado +passwordCambiada')

        if (!usuarioBDD) {
            return res.status(404).json({ msg: 'El usuario no se encuentra registrado' })
        }

        if (usuarioBDD.estado === 'inactivo') {
            return res.status(403).json({ msg: 'Tu cuenta ha sido suspendida. Contacta con el administrador.' })
        }

        const passwordValido = await usuarioBDD.matchPassword(password)
        if (!passwordValido) {
            return res.status(401).json({ msg: 'La contraseña no es correcta' })
        }

        const token = crearTokenJWT(usuarioBDD._id, usuarioBDD.rol)

        const respuesta = {
            token,
            _id:               usuarioBDD._id,
            nombre:            usuarioBDD.nombre,
            apellido:          usuarioBDD.apellido,
            email:             usuarioBDD.email,
            cedula:            usuarioBDD.cedula,
            telefono:          usuarioBDD.telefono,
            rol:               usuarioBDD.rol,
            barriosAsignados:  usuarioBDD.barriosAsignados,
        }

        // Avisar al frontend si debe forzar cambio de contraseña
        if (!usuarioBDD.passwordCambiada) {
            respuesta.requiereCambioPassword = true
            respuesta.msg = 'Debes cambiar tu contraseña inicial antes de continuar.'
        }

        res.status(200).json(respuesta)

    } catch (error) {
        console.error('❌ Error en login:', error.message)
        res.status(500).json({ success: false, msg: 'Error interno del servidor', error: error.message })
    }
}

// ── CERRAR SESIÓN ─────────────────────────────────────────────────────────────
export const cerrarSesion = async (req, res) => {
    try {
        const token = req.tokenActual
        if (!token) {
            return res.status(400).json({ msg: 'No se encontró el token en la solicitud' })
        }
        const expiresAt = obtenerExpiracionToken(token)
        await TokenBlacklist.create({ token, expiresAt })
        res.status(200).json({ msg: 'Sesión cerrada correctamente' })
    } catch (error) {
        if (error.code === 11000) {
            return res.status(200).json({ msg: 'La sesión ya había sido cerrada anteriormente' })
        }
        console.error('❌ Error al cerrar sesión:', error.message)
        res.status(500).json({ success: false, msg: 'Error interno del servidor', error: error.message })
    }
}

// ── RECUPERAR CONTRASEÑA — solicitar código OTP ───────────────────────────────
export const recuperarPassword = async (req, res) => {
    try {
        const { email } = req.body

        if (!email) {
            return res.status(400).json({ msg: 'Debes ingresar tu correo' })
        }

        const usuarioBDD = await Usuario.findOne({ email: email.toLowerCase() })
            .select('+token +tokenExpira +estado')

        if (!usuarioBDD) {
            return res.status(404).json({ msg: 'El usuario no se encuentra registrado' })
        }

        if (usuarioBDD.estado === 'inactivo') {
            return res.status(403).json({ msg: 'Tu cuenta ha sido suspendida.' })
        }

        const codigo = usuarioBDD.createTokenRecuperacion()  // genera OTP de 6 dígitos, expira en 15 min
        await usuarioBDD.save()

        await sendMailRecuperarPassword(email, codigo)

        res.status(200).json({ msg: 'Revisa tu correo. Te enviamos un código de 6 dígitos que expira en 15 minutos.' })

    } catch (error) {
        console.error('❌ Error en recuperarPassword:', error.message)
        res.status(500).json({ success: false, msg: 'Error interno del servidor', error: error.message })
    }
}

// ── RESTABLECER CONTRASEÑA CON CÓDIGO OTP (un solo paso) ─────────────────────
export const restablecerPasswordConCodigo = async (req, res) => {
    try {
        const { email, codigo, passwordNueva } = req.body

        if (!email || !codigo || !passwordNueva) {
            return res.status(400).json({ msg: 'Debes enviar el correo, el código y la nueva contraseña' })
        }

        const usuarioBDD = await Usuario.findOne({ email: email.toLowerCase() })
            .select('+token +tokenExpira')

        if (!usuarioBDD) {
            return res.status(404).json({ msg: 'El usuario no se encuentra registrado' })
        }

        // Verificar código y expiración
        if (!usuarioBDD.token || usuarioBDD.token !== codigo.toString()) {
            return res.status(400).json({ msg: 'Código incorrecto o expirado.' })
        }

        if (!usuarioBDD.tokenExpira || usuarioBDD.tokenExpira < new Date()) {
            // Limpiar token expirado
            usuarioBDD.token       = null
            usuarioBDD.tokenExpira = null
            await usuarioBDD.save()
            return res.status(400).json({ msg: 'Código incorrecto o expirado.' })
        }

        // Actualizar contraseña y limpiar código
        usuarioBDD.password         = await usuarioBDD.encryptPassword(passwordNueva)
        usuarioBDD.token            = null
        usuarioBDD.tokenExpira      = null
        usuarioBDD.passwordCambiada = true
        await usuarioBDD.save()

        res.status(200).json({ msg: '¡Contraseña actualizada! Ya puedes iniciar sesión.' })

    } catch (error) {
        console.error('❌ Error en restablecerPasswordConCodigo:', error.message)
        res.status(500).json({ success: false, msg: 'Error interno del servidor', error: error.message })
    }
}

// ── CAMBIAR CONTRASEÑA (usuario autenticado) ──────────────────────────────────
export const cambiarPassword = async (req, res) => {
    try {
        const { passwordActual, passwordNueva } = req.body

        if (!passwordActual || !passwordNueva) {
            return res.status(400).json({ msg: 'Debes enviar la contraseña actual y la nueva' })
        }

        const usuarioBDD = await Usuario.findById(req.usuarioBDD._id)

        const valido = await usuarioBDD.matchPassword(passwordActual)
        if (!valido) {
            return res.status(400).json({ msg: 'La contraseña actual no es correcta' })
        }

        usuarioBDD.password         = await usuarioBDD.encryptPassword(passwordNueva)
        usuarioBDD.passwordCambiada = true
        await usuarioBDD.save()

        // Notificar por correo (no bloquea si falla)
        try {
            await sendMailPasswordCambiada(usuarioBDD.email, usuarioBDD.nombre)
        } catch (e) {
            console.error('⚠️ No se pudo enviar correo de notificación:', e.message)
        }

        res.status(200).json({ msg: 'Contraseña actualizada correctamente' })

    } catch (error) {
        console.error('❌ Error en cambiarPassword:', error.message)
        res.status(500).json({ success: false, msg: 'Error interno del servidor', error: error.message })
    }
}

// ── PERFIL DEL USUARIO AUTENTICADO ───────────────────────────────────────────
export const perfil = (req, res) => {
    try {
        const { password, token, tokenExpira, estado, passwordCambiada, __v, ...datos } = req.usuarioBDD
        res.status(200).json(datos)
    } catch (error) {
        res.status(500).json({ success: false, msg: 'Error interno del servidor', error: error.message })
    }
}
