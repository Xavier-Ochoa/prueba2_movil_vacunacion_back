import nodemailer from 'nodemailer'

const transporter = nodemailer.createTransport({
    service: 'gmail',
    auth: {
        user: process.env.EMAIL_USER,
        pass: process.env.EMAIL_PASS,   // App Password de Gmail
    },
})

/**
 * Función base para enviar correos HTML
 * @param {string} destino  - Email del destinatario
 * @param {string} asunto   - Asunto del correo
 * @param {string} html     - Contenido HTML
 */
export const sendMail = async (destino, asunto, html) => {
    await transporter.sendMail({
        from: `"Sistema de Vacunación" <${process.env.EMAIL_USER}>`,
        to: destino,
        subject: asunto,
        html,
    })
}
