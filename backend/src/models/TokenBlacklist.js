import { Schema, model } from 'mongoose'

const tokenBlacklistSchema = new Schema({
    token: {
        type: String,
        required: true,
        unique: true,
    },
    expiresAt: {
        type: Date,
        required: true,
        index: { expires: 0 },  // TTL: Mongo elimina el doc cuando llega la fecha
    },
})

export default model('TokenBlacklist', tokenBlacklistSchema, 'token_blacklist')
