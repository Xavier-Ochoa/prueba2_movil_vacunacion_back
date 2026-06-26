import { Schema, model } from 'mongoose'
import bcrypt from 'bcryptjs'

/**
 * Modelo de Usuario — colección 'usuarios'
 *
 * Roles del sistema:
 *   - coordinador_campana  → crea coordinadores de brigada, gestiona barrios
 *   - coordinador_brigada  → crea vacunadores, tiene barrios asignados
 *   - vacunador            → registra vacunaciones
 *
 * El coordinador_campana se crea directamente en la DB (no por endpoint).
 * Los demás roles son creados por el rol superior.
 */
const usuarioSchema = new Schema(
    {
        // ─────────────────────────────────────────────
        // CAMPOS PRINCIPALES
        // ─────────────────────────────────────────────
        nombre: {
            type: String,
            required: [true, 'El nombre es obligatorio'],
            trim: true,
        },
        apellido: {
            type: String,
            required: [true, 'El apellido es obligatorio'],
            trim: true,
        },
        cedula: {
            type: String,
            required: [true, 'La cédula es obligatoria'],
            unique: true,
            trim: true,
        },
        email: {
            type: String,
            required: [true, 'El correo es obligatorio'],
            unique: true,
            trim: true,
            lowercase: true,
        },
        telefono: {
            type: String,
            required: [true, 'El teléfono es obligatorio'],
            trim: true,
        },
        password: {
            type: String,
            required: [true, 'La contraseña es obligatoria'],
        },
        rol: {
            type: String,
            enum: {
                values: ['coordinador_campana', 'coordinador_brigada', 'vacunador'],
                message: 'Rol inválido',
            },
            required: [true, 'El rol es obligatorio'],
        },

        // ─────────────────────────────────────────────
        // CAMPOS AUTOMÁTICOS
        // ─────────────────────────────────────────────
        estado: {
            type: String,
            enum: ['activo', 'inactivo'],
            default: 'activo',
            select: false,
        },

        /**
         * true  → el usuario ya cambió su contraseña inicial (Ecuador2026)
         * false → debe cambiar la contraseña en el primer login
         */
        passwordCambiada: {
            type: Boolean,
            default: false,
            select: false,
        },

        // Token para recuperación de contraseña
        token: {
            type: String,
            default: null,
            select: false,
        },
        tokenExpira: {
            type: Date,
            default: null,
            select: false,
        },

        // ─────────────────────────────────────────────
        // RELACIONES
        // ─────────────────────────────────────────────

        /**
         * Quién creó a este usuario.
         * - coordinador_brigada → fue creado por un coordinador_campana
         * - vacunador           → fue creado por un coordinador_brigada
         */
        creadoPor: {
            type: Schema.Types.ObjectId,
            ref: 'Usuario',
            default: null,
        },

        /**
         * Barrios asignados (aplica a coordinador_brigada y vacunador).
         * Cada elemento referencia un documento de la colección 'barrios'.
         */
        barriosAsignados: [
            {
                type: Schema.Types.ObjectId,
                ref: 'Barrio',
            },
        ],
    },
    {
        timestamps: true,
    }
)

// ─────────────────────────────────────────────
// MÉTODOS
// ─────────────────────────────────────────────

usuarioSchema.methods.encryptPassword = async function (password) {
    const salt = await bcrypt.genSalt(10)
    return bcrypt.hash(password, salt)
}

usuarioSchema.methods.matchPassword = async function (password) {
    return bcrypt.compare(password, this.password)
}

usuarioSchema.methods.createTokenRecuperacion = function () {
    const tokenGenerado = Math.floor(100000 + Math.random() * 900000).toString()  // código OTP de 6 dígitos
    this.token       = tokenGenerado
    this.tokenExpira = new Date(Date.now() + 15 * 60 * 1000)  // 15 minutos
    return tokenGenerado
}

export default model('Usuario', usuarioSchema, 'usuarios')
