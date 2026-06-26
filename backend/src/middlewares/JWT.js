import jwt from 'jsonwebtoken'
import Usuario from '../models/Usuario.js'
import TokenBlacklist from '../models/TokenBlacklist.js'

// ── Crear token (expira en 1 día) ─────────────────────────────────────────────
export const crearTokenJWT = (id, rol) => {
    return jwt.sign({ id, rol }, process.env.JWT_SECRET, { expiresIn: '1d' })
}

// ── Obtener fecha de expiración del token (para blacklist) ────────────────────
export const obtenerExpiracionToken = (token) => {
    const { exp } = jwt.decode(token)
    return new Date(exp * 1000)
}

// ── Middleware principal: verifica token y adjunta usuario a req ──────────────
export const verificarTokenJWT = async (req, res, next) => {
    const { authorization } = req.headers

    if (!authorization) {
        return res.status(401).json({ msg: 'Acceso denegado: token no proporcionado' })
    }

    try {
        const token = authorization.split(' ')[1]

        // Verificar si el token fue invalidado (logout)
        const tokenInvalidado = await TokenBlacklist.findOne({ token })
        if (tokenInvalidado) {
            return res.status(401).json({ msg: 'Sesión cerrada. Por favor inicia sesión nuevamente.' })
        }

        // Verificar firma y expiración
        const { id, rol } = jwt.verify(token, process.env.JWT_SECRET)

        // Buscar usuario en DB
        const usuarioBDD = await Usuario.findById(id)
            .lean()
            .select('+estado +passwordCambiada')

        if (!usuarioBDD) {
            return res.status(401).json({ msg: 'Usuario no encontrado' })
        }

        if (usuarioBDD.estado === 'inactivo') {
            return res.status(403).json({ msg: 'Tu cuenta ha sido suspendida. Contacta con el administrador.' })
        }

        req.usuarioBDD   = usuarioBDD
        req.tokenActual  = token

        next()
    } catch (error) {
        console.error('Error JWT:', error.message)
        return res.status(401).json({ msg: `Token inválido o expirado: ${error.message}` })
    }
}

// ── Middleware: solo Coordinador de Campaña ───────────────────────────────────
export const verificarCoordinadorCampana = (req, res, next) => {
    if (req.usuarioBDD.rol !== 'coordinador_campana') {
        return res.status(403).json({ msg: 'Acceso denegado: se requiere rol de Coordinador de Campaña' })
    }
    next()
}

// ── Middleware: solo Coordinador de Brigada ───────────────────────────────────
export const verificarCoordinadorBrigada = (req, res, next) => {
    if (req.usuarioBDD.rol !== 'coordinador_brigada') {
        return res.status(403).json({ msg: 'Acceso denegado: se requiere rol de Coordinador de Brigada' })
    }
    next()
}

// ── Middleware: Coordinador de Campaña o de Brigada ───────────────────────────
export const verificarCoordinador = (req, res, next) => {
    const rolesPermitidos = ['coordinador_campana', 'coordinador_brigada']
    if (!rolesPermitidos.includes(req.usuarioBDD.rol)) {
        return res.status(403).json({ msg: 'Acceso denegado: se requiere rol de Coordinador' })
    }
    next()
}

// ── Middleware: primer login — obliga a cambiar contraseña ────────────────────
export const verificarPasswordCambiada = (req, res, next) => {
    if (!req.usuarioBDD.passwordCambiada) {
        return res.status(403).json({
            msg: 'Debes cambiar tu contraseña inicial antes de continuar.',
            requiereCambioPassword: true,
        })
    }
    next()
}
