# Definition of Done — BudSound

Una historia de usuario o ítem del backlog se considera terminado cuando
cumple **todos** los siguientes criterios:

1. **Código integrado:** el código vive en la rama principal del
   repositorio, con un commit descriptivo de qué cambia y por qué.
2. **Probado de forma real:** la funcionalidad se probó a mano en el
   emulador Android y/o en un dispositivo físico (tablet), no solo
   leyendo el código. Para una historia que involucra al Participante y
   al DJ a la vez (ej. una solicitud de canción), se probó con ambos
   roles interactuando en vivo.
3. **Validado en el backend:** cualquier regla de negocio crítica
   (montos, límites de tiempo, permisos por rol) se valida en el
   backend, nunca solo en la app — la app puede validar además, pero no
   en su lugar.
4. **Sin información sensible expuesta:** ninguna contraseña, token
   completo de sesión, ni credencial de un servicio externo queda
   expuesta en un log, una respuesta de error o el código fuente.
5. **Resiliente a la falta de credenciales externas:** si la
   funcionalidad depende de un servicio de terceros (MercadoPago, Google,
   Brevo), sigue existiendo un camino funcional cuando esas credenciales
   no están cargadas (modo simulado o la función queda inactiva sin
   romper el resto de la app).
6. **No rompe lo que ya funcionaba:** se revisó que la pantalla o flujo
   tocado no rompiera visualmente otra parte de la app ya entregada, en
   al menos un dispositivo.
7. **Documentado si es una decisión, no solo código:** si la historia
   implicó una decisión de arquitectura o de producto (no un detalle de
   implementación obvio), queda una entrada en `CLAUDE.md` o
   `DECISIONES_TECNICAS.md` explicando el porqué.
8. **Desplegable:** el cambio se puede llevar a producción (Railway) sin
   pasos manuales adicionales no documentados.
