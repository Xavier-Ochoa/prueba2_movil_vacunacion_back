import { Router } from 'express'
import {
    crearCoordinadorBrigada,
    crearVacunador,
    listarMisUsuarios,
    obtenerUsuario,
    editarUsuario,
    actualizarBarriosCoordinador,
    reasignarBarrioVacunador,
    desactivarUsuario,
    activarUsuario,
} from '../controllers/usuario_controller.js'
import {
    verificarTokenJWT,
    verificarCoordinadorCampana,
    verificarCoordinadorBrigada,
    verificarPasswordCambiada,
} from '../middlewares/JWT.js'

const router = Router()

// Todas las rutas requieren token válido y contraseña cambiada
router.use(verificarTokenJWT, verificarPasswordCambiada)

// ── Solo Coordinador de Campaña ────────────────────────────────────────────────
router.post('/coordinador-brigada',         verificarCoordinadorCampana, crearCoordinadorBrigada)
router.put('/:id/barrios',                  verificarCoordinadorCampana, actualizarBarriosCoordinador)

// ── Solo Coordinador de Brigada ────────────────────────────────────────────────
router.post('/vacunador',                   verificarCoordinadorBrigada, crearVacunador)
router.put('/:id/reasignar-barrio',         verificarCoordinadorBrigada, reasignarBarrioVacunador)

// ── Coordinadores (cualquiera) ─────────────────────────────────────────────────
router.get('/mis-usuarios',                 listarMisUsuarios)
router.get('/:id',                          obtenerUsuario)
router.put('/:id',                          editarUsuario)
router.patch('/:id/desactivar',             desactivarUsuario)
router.patch('/:id/activar',                activarUsuario)

export default router
