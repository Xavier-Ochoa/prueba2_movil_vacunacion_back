import { Router } from 'express'
import {
    login,
    cerrarSesion,
    recuperarPassword,
    restablecerPasswordConCodigo,
    cambiarPassword,
    perfil,
} from '../controllers/auth_controller.js'
import { verificarTokenJWT } from '../middlewares/JWT.js'

const router = Router()

// ── Rutas públicas ─────────────────────────────────────────────────────────────
router.post('/login',                    login)
router.post('/recuperar-password',       recuperarPassword)
router.post('/restablecer-password',     restablecerPasswordConCodigo)

// ── Rutas protegidas ───────────────────────────────────────────────────────────
router.post('/logout',              verificarTokenJWT, cerrarSesion)
router.post('/cambiar-password',    verificarTokenJWT, cambiarPassword)
router.get('/perfil',               verificarTokenJWT, perfil)

export default router
