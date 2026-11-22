/* Le dice a Telegram que mande los mensajes del bot a la API de Vercel (webhook), o vuelve al modo
 * "la PC pregunta" (long polling) con --quitar.
 *   node --env-file=.env scripts/registrar-webhook.mjs https://dermalia-web.vercel.app
 *   node --env-file=.env scripts/registrar-webhook.mjs --quitar
 * Usa TELEGRAM_BOT_TOKEN y TELEGRAM_WEBHOOK_SECRET del .env (el mismo secreto que va en Vercel). */
const token = process.env.TELEGRAM_BOT_TOKEN;
const secreto = process.env.TELEGRAM_WEBHOOK_SECRET;
const destino = process.argv[2];
if (!token || !destino) { console.error('Falta TELEGRAM_BOT_TOKEN en el .env o la URL del sitio.'); process.exit(1); }

async function telegram(metodo, cuerpo) {
  const r = await fetch(`https://api.telegram.org/bot${token}/${metodo}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(cuerpo ?? {}) });
  const datos = await r.json();
  if (!datos.ok) throw new Error(datos.description);
  return datos.result;
}

if (destino === '--quitar') {
  await telegram('deleteWebhook', { drop_pending_updates: false });
  console.log('Webhook quitado: el bot vuelve a funcionar con la API de tu PC (npm run api).');
} else {
  if (!secreto) { console.error('Falta TELEGRAM_WEBHOOK_SECRET en el .env.'); process.exit(1); }
  const url = `${destino.replace(/\/+$/, '')}/api/telegram`;
  await telegram('setWebhook', { url, secret_token: secreto, allowed_updates: ['message', 'callback_query'] });
  const info = await telegram('getWebhookInfo');
  console.log(`Webhook registrado en ${info.url} (pendientes: ${info.pending_update_count}${info.last_error_message ? `, último error: ${info.last_error_message}` : ''}).`);
}
