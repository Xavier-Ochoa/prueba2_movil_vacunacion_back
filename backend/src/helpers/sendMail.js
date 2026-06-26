import { sendMail } from '../config/nodemailer.js'

/**
 * Correo de bienvenida con credenciales iniciales
 * Se envía cuando un coordinador crea un usuario nuevo.
 *
 * @param {string} destino   - Email del nuevo usuario
 * @param {string} nombre    - Nombre completo
 * @param {string} rol       - Rol asignado
 * @param {string} password  - Contraseña inicial (Ecuador2026)
 */
export const sendMailCredenciales = (destino, nombre, rol, password) => {
    const rolesLabel = {
        coordinador_brigada: 'Coordinador de Brigada',
        vacunador:           'Vacunador',
    }

    return sendMail(
        destino,
        '🩺 Bienvenido al Sistema de Vacunación — Tus credenciales de acceso',
        `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 28px;
                    border: 1px solid #e0e0e0; border-radius: 12px; background: #ffffff;">

            <div style="text-align: center; margin-bottom: 24px;">
                <h1 style="color: #1565c0; margin: 0 0 6px 0;">🩺 Sistema de Vacunación</h1>
                <p style="color: #666; font-size: 15px; margin: 0;">Quito - Ecuador</p>
            </div>

            <p style="color: #333; font-size: 15px; line-height: 1.7; margin-bottom: 20px;">
                Hola <strong>${nombre}</strong>, tu cuenta ha sido creada exitosamente.<br>
                Has sido registrado como <strong>${rolesLabel[rol] || rol}</strong>.
            </p>

            <div style="background: #e3f2fd; border: 2px dashed #1565c0; border-radius: 10px;
                        padding: 24px 20px; text-align: center; margin-bottom: 24px;">
                <p style="margin: 0 0 16px 0; font-size: 13px; color: #555; font-weight: 600;
                           text-transform: uppercase; letter-spacing: 0.08em;">
                    🔑 Tus credenciales de acceso
                </p>
                <table style="margin: 0 auto; font-size: 15px; color: #1a237e; text-align: left;
                              border-collapse: collapse;">
                    <tr>
                        <td style="padding: 6px 12px 6px 0; font-weight: 600;">Correo:</td>
                        <td style="padding: 6px 0; font-family: monospace; background: #fff;
                                   padding: 6px 12px; border-radius: 4px;">${destino}</td>
                    </tr>
                    <tr>
                        <td style="padding: 6px 12px 6px 0; font-weight: 600;">Contraseña:</td>
                        <td style="padding: 6px 0; font-family: monospace; font-size: 17px;
                                   font-weight: 700; background: #fff; padding: 6px 12px;
                                   border-radius: 4px; letter-spacing: 0.1em;">${password}</td>
                    </tr>
                </table>
            </div>

            <div style="background: #fff8e1; border-left: 4px solid #f9a825; border-radius: 6px;
                        padding: 14px 18px; margin-bottom: 24px;">
                <p style="margin: 0; color: #333; font-size: 14px; line-height: 1.8;">
                    <strong>⚠️ Importante:</strong> Al ingresar por primera vez, el sistema te pedirá
                    que cambies tu contraseña. Elige una contraseña segura y no la compartas.
                </p>
            </div>

            <hr style="border: none; border-top: 1px solid #e0e0e0; margin: 24px 0;">

            <footer style="text-align: center; color: #aaa; font-size: 12px;">
                <p style="margin: 4px 0;"><strong style="color: #1565c0;">Sistema de Vacunación</strong></p>
                <p style="margin: 4px 0;">Ministerio de Salud · Quito, Ecuador</p>
                <p style="margin: 12px 0 0 0; color: #bbb;">
                    Este es un mensaje automático, por favor no respondas a este correo.
                </p>
            </footer>
        </div>
        `
    )
}

/**
 * Correo de recuperación de contraseña con código OTP de 6 dígitos
 *
 * @param {string} destino - Email del usuario
 * @param {string} codigo  - Código OTP de 6 dígitos (expira en 15 minutos)
 */
export const sendMailRecuperarPassword = (destino, codigo) => {
    return sendMail(
        destino,
        '🔐 Recuperación de contraseña — Sistema de Vacunación',
        `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 28px;
                    border: 1px solid #e0e0e0; border-radius: 12px; background: #ffffff;">

            <div style="text-align: center; margin-bottom: 24px;">
                <h1 style="color: #d32f2f; margin: 0 0 6px 0;">🔐 Recuperación de Contraseña</h1>
                <p style="color: #666; font-size: 15px; margin: 0;">Sistema de Vacunación · Quito</p>
            </div>

            <p style="color: #333; font-size: 15px; line-height: 1.7; margin-bottom: 24px;">
                Recibimos una solicitud para restablecer tu contraseña. Ingresa el código de abajo
                en la aplicación. Si no fuiste tú, ignora este mensaje.
            </p>

            <div style="background: #fff5f5; border: 2px dashed #d32f2f; border-radius: 10px;
                        padding: 28px 20px; text-align: center; margin-bottom: 24px;">
                <p style="margin: 0 0 10px 0; font-size: 13px; color: #555; font-weight: 600;
                           text-transform: uppercase; letter-spacing: 0.08em;">
                    🔑 Tu código de verificación
                </p>
                <p style="margin: 0; font-size: 42px; font-weight: 700; letter-spacing: 0.25em;
                           color: #c62828; font-family: 'Courier New', monospace;
                           background: #ffffff; border-radius: 8px; padding: 16px 24px;
                           display: inline-block; border: 1px solid #f5c5c5;">
                    ${codigo}
                </p>
                <p style="margin: 16px 0 0 0; font-size: 13px; color: #888;">
                    ⏱ Este código expira en <strong>15 minutos</strong>.
                </p>
            </div>

            <div style="background: #ffebee; border-radius: 8px; padding: 14px 18px;
                        border-left: 4px solid #d32f2f; margin-bottom: 24px;">
                <p style="margin: 0; color: #333; font-size: 13px;">
                    <strong>⚠️ Importante:</strong> No compartas este código con nadie. Expira
                    en 15 minutos y solo puede usarse una vez.
                </p>
            </div>

            <hr style="border: none; border-top: 1px solid #e0e0e0; margin: 24px 0;">

            <footer style="text-align: center; color: #aaa; font-size: 12px;">
                <p style="margin: 4px 0;"><strong style="color: #1565c0;">Sistema de Vacunación</strong></p>
                <p style="margin: 4px 0;">Ministerio de Salud · Quito, Ecuador</p>
            </footer>
        </div>
        `
    )
}

/**
 * Correo de notificación de cambio de contraseña exitoso
 *
 * @param {string} destino - Email del usuario
 * @param {string} nombre  - Nombre del usuario
 */
export const sendMailPasswordCambiada = (destino, nombre) => {
    const fecha = new Date().toLocaleString('es-EC', {
        timeZone: 'America/Guayaquil',
        dateStyle: 'full',
        timeStyle: 'short',
    })

    return sendMail(
        destino,
        '🔒 Tu contraseña fue cambiada — Sistema de Vacunación',
        `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 28px;
                    border: 1px solid #e0e0e0; border-radius: 12px; background: #ffffff;">

            <div style="text-align: center; margin-bottom: 24px;">
                <h1 style="color: #1a3c5e; margin: 0 0 6px 0;">🔒 Contraseña Actualizada</h1>
                <p style="color: #666; font-size: 15px; margin: 0;">Sistema de Vacunación · Quito</p>
            </div>

            <p style="color: #333; font-size: 15px; line-height: 1.7; margin-bottom: 20px;">
                Hola <strong>${nombre}</strong>, tu contraseña fue actualizada exitosamente.
            </p>

            <div style="background: #f0f7f0; border: 2px solid #2e7d32; border-radius: 10px;
                        padding: 20px 24px; text-align: center; margin-bottom: 24px;">
                <p style="margin: 0 0 6px 0; font-size: 13px; color: #555; font-weight: 600;
                           text-transform: uppercase; letter-spacing: 0.08em;">
                    ✅ Cambio registrado el
                </p>
                <p style="margin: 0; font-size: 16px; font-weight: 700; color: #2e7d32;">
                    ${fecha}
                </p>
            </div>

            <div style="background: #fff3e0; border-radius: 8px; padding: 16px 20px;
                        border-left: 4px solid #ff9800; margin-bottom: 24px;">
                <p style="margin: 0 0 6px 0; color: #e65100; font-size: 14px; font-weight: 700;">
                    ⚠️ ¿No reconoces este cambio?
                </p>
                <p style="margin: 0; color: #444; font-size: 14px; line-height: 1.8;">
                    Si no fuiste tú, contacta inmediatamente al administrador del sistema.
                </p>
            </div>

            <hr style="border: none; border-top: 1px solid #e0e0e0; margin: 24px 0;">

            <footer style="text-align: center; color: #aaa; font-size: 12px;">
                <p style="margin: 4px 0;"><strong style="color: #1565c0;">Sistema de Vacunación</strong></p>
                <p style="margin: 4px 0;">Ministerio de Salud · Quito, Ecuador</p>
            </footer>
        </div>
        `
    )
}
