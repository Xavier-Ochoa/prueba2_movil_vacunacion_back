import { Schema, model } from 'mongoose'

/**
 * Modelo de Barrio — colección 'barrios'
 *
 * Cada barrio pertenece a un sector de Quito.
 * Los 25 barrios se precargan con el seeder.
 * Un barrio puede estar asignado a un coordinador_brigada.
 */
const barrioSchema = new Schema(
    {
        nombre: {
            type: String,
            required: [true, 'El nombre del barrio es obligatorio'],
            unique: true,
            trim: true,
        },

        /**
         * Sector de Quito al que pertenece el barrio.
         * Se asigna automáticamente según el barrio.
         */
        sector: {
            type: String,
            required: [true, 'El sector es obligatorio'],
            enum: {
                values: ['Norte', 'Centro Norte', 'Centro', 'Sur', 'Valles'],
                message: 'Sector inválido',
            },
            trim: true,
        },

        /**
         * Coordinador de Brigada asignado a este barrio.
         * null = barrio sin asignar.
         */
        coordinadorAsignado: {
            type: Schema.Types.ObjectId,
            ref: 'Usuario',
            default: null,
        },

        estado: {
            type: String,
            enum: ['activo', 'inactivo'],
            default: 'activo',
        },
    },
    {
        timestamps: true,
    }
)

export default model('Barrio', barrioSchema, 'barrios')
