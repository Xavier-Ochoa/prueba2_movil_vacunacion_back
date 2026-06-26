import { Schema, model } from 'mongoose'

/**
 * Modelo de Vacunación — colección 'vacunaciones'
 *
 * Registrado por un vacunador.
 * Incluye datos del propietario, mascota, vacuna, GPS e imagen.
 */
const vacunacionSchema = new Schema(
    {
        // ─────────────────────────────────────────────
        // PROPIETARIO
        // ─────────────────────────────────────────────
        propietario: {
            nombre: {
                type: String,
                required: [true, 'El nombre del propietario es obligatorio'],
                trim: true,
            },
            cedula: {
                type: String,
                required: [true, 'La cédula del propietario es obligatoria'],
                trim: true,
            },
            telefono: {
                type: String,
                required: [true, 'El teléfono del propietario es obligatorio'],
                trim: true,
            },
        },

        // ─────────────────────────────────────────────
        // MASCOTA
        // ─────────────────────────────────────────────
        mascota: {
            tipo: {
                type: String,
                enum: {
                    values: ['perro', 'gato'],
                    message: 'El tipo de mascota debe ser perro o gato',
                },
                required: [true, 'El tipo de mascota es obligatorio'],
            },
            nombre: {
                type: String,
                required: [true, 'El nombre de la mascota es obligatorio'],
                trim: true,
            },
            edad: {
                type: Number,
                required: [true, 'La edad de la mascota es obligatoria'],
                min: [0, 'La edad no puede ser negativa'],
            },
            sexo: {
                type: String,
                enum: {
                    values: ['macho', 'hembra'],
                    message: 'El sexo debe ser macho o hembra',
                },
                required: [true, 'El sexo de la mascota es obligatorio'],
            },
        },

        // ─────────────────────────────────────────────
        // VACUNA
        // ─────────────────────────────────────────────
        vacuna: {
            type: String,
            required: [true, 'La vacuna aplicada es obligatoria'],
            trim: true,
        },

        observaciones: {
            type: String,
            trim: true,
            default: '',
        },

        // ─────────────────────────────────────────────
        // IMAGEN (Cloudinary)
        // ─────────────────────────────────────────────
        imagenUrl: {
            type: String,
            required: [true, 'La fotografía es obligatoria'],
        },
        imagenPublicId: {
            type: String, // ID en Cloudinary para poder eliminarla
            default: null,
        },

        // ─────────────────────────────────────────────
        // UBICACIÓN GPS (opcional)
        // ─────────────────────────────────────────────
        ubicacion: {
            latitud: {
                type: Number,
                default: null,
            },
            longitud: {
                type: Number,
                default: null,
            },
        },

        // ─────────────────────────────────────────────
        // RELACIONES
        // ─────────────────────────────────────────────
        vacunador: {
            type: Schema.Types.ObjectId,
            ref: 'Usuario',
            required: [true, 'El vacunador es obligatorio'],
        },

        barrio: {
            type: Schema.Types.ObjectId,
            ref: 'Barrio',
            required: [true, 'El barrio es obligatorio'],
        },

        // ─────────────────────────────────────────────
        // SOPORTE OFFLINE / SINCRONIZACIÓN (Sprint 3)
        // ─────────────────────────────────────────────

        /**
         * Fecha real en la que se aplicó la vacuna, registrada por el
         * vacunador en el dispositivo (puede ser muy anterior a la fecha
         * en que el registro finalmente llega al servidor).
         * Si el cliente no la envía, se usa fechaRegistro como respaldo.
         */
        fechaRegistro: {
            type: Date,
            default: Date.now,
        },

        /**
         * Fecha en la que el backend efectivamente guardó el documento
         * (llegada real a MongoDB). Útil para distinguir trabajo hecho
         * en campo sin señal vs. el momento de la sincronización.
         */
        fechaSincronizacion: {
            type: Date,
            default: Date.now,
        },

        /**
         * Identificador único generado en el dispositivo (uuid) en el
         * momento de crear el registro localmente, ANTES de tener
         * conexión. Permite detectar reintentos duplicados: si la app
         * reenvía el mismo registro (p. ej. porque no recibió la
         * respuesta a tiempo), el backend reconoce el clienteId y no
         * lo inserta dos veces.
         */
        clienteId: {
            type: String,
            default: null,
            index: true,
            unique: true,
            sparse: true, // permite múltiples null (registros creados directo en el backend/Postman)
        },
    },
    {
        timestamps: true,
    }
)

export default model('Vacunacion', vacunacionSchema, 'vacunaciones')
