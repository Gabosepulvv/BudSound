# Product Vision — BudSound

## El problema

En discotecas, bares y eventos en vivo, el público que quiere pedirle una
canción al DJ no tiene ninguna forma ordenada de hacerlo: se acerca
físicamente a gritar el pedido, interrumpe al DJ a mitad del set, y este
no tiene ningún criterio objetivo para decidir qué pedidos considerar ni
en qué orden llegaron. No existe registro de lo que se pidió, nadie sabe
si el DJ realmente vio el pedido, y el DJ pierde el control de su propio
show cada vez que alguien se le acerca a la cabina.

## Para quién

- **DJs** que tocan en vivo en discotecas, bares, fiestas y eventos
  masivos, y quieren mantener el control artístico de su set sin perder
  la conexión con el público.
- **Participantes**: el público asistente a esos eventos, que quiere
  pedir una canción específica y saber si su pedido será considerado.

## La propuesta de valor

BudSound digitaliza ese canal: el Participante escanea el código QR del
evento, busca la canción que quiere (por título o artista, usando
metadatos públicos — la app nunca reproduce audio) y envía su solicitud
acompañada de una propina obligatoria como incentivo para el DJ. El DJ ve
las solicitudes en una cola ordenada estrictamente por orden de llegada
(nunca por quién pagó más) y decide libremente, con un plazo de 7
minutos, si acepta o rechaza cada una. El dinero de la propina solo se
cobra si el DJ acepta — si rechaza, no se cobra nada.

A diferencia de gritarle al DJ, mandarle un mensaje al encargado del
local, o simplemente no poder pedir nada, BudSound le da al Participante
una vía directa y con seguimiento en tiempo real, y le da al DJ una cola
ordenada, un incentivo económico adicional a su cachet, y nunca le quita
el control artístico de su propio evento.

## Qué NO es BudSound

- No es un reproductor de música ni compite con Spotify/YouTube: la
  canción solicitada nunca suena dentro de la app, siempre se reproduce
  desde el equipo del propio DJ. Esta es una decisión legal explícita
  (ver `CLAUDE.md`), no una limitación técnica.
- La propina **nunca** garantiza que la canción se toque ni compra
  prioridad en la cola — es un incentivo al DJ, que él evalúa libremente.
- BudSound no concentra el dinero de terceros: cada DJ cobra directo en
  su propia cuenta de MercadoPago (split de pagos), y la plataforma solo
  retiene su comisión.

## Usuarios objetivo (alcance del MVP)

Chile, como mercado inicial (moneda CLP, MercadoPago Chile). Cualquier
recinto con eventos en vivo con DJ: discotecas, bares, fiestas privadas y
eventos masivos.

## Métricas de éxito (orientativas para el MVP/demo)

- Un Participante puede ir de "escanear el QR" a "solicitud aceptada en
  la cola del DJ" sin fricción y en tiempo real.
- Un DJ puede cerrar un evento y ver cuánto recaudó y cuántas canciones
  aceptó, sin cálculos manuales.
- El flujo completo se puede demostrar de punta a punta sin depender de
  dinero real (modo de pago simulado), para pruebas y presentaciones.
