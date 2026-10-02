const { pool } = require('../config/db');

async function crear({ requestId, montoBrutoClp, comisionClp, montoNetoClp, mpPaymentId, status }) {
  const { rows } = await pool.query(
    `INSERT INTO transactions
       (request_id, monto_bruto_clp, comision_clp, monto_neto_clp, mp_payment_id, status)
     VALUES ($1, $2, $3, $4, $5, $6)
     RETURNING *`,
    [requestId, montoBrutoClp, comisionClp, montoNetoClp, mpPaymentId || null, status || 'PENDIENTE'],
  );
  return rows[0];
}

async function actualizarStatus(id, status, mpPaymentId) {
  const { rows } = await pool.query(
    `UPDATE transactions SET status = $2, mp_payment_id = COALESCE($3, mp_payment_id)
     WHERE id = $1
     RETURNING *`,
    [id, status, mpPaymentId || null],
  );
  return rows[0] || null;
}

async function buscarPorRequestId(requestId) {
  const { rows } = await pool.query('SELECT * FROM transactions WHERE request_id = $1', [requestId]);
  return rows[0] || null;
}

// Usado por el webhook de MercadoPago para mapear una notificación (que
// solo trae el id del pago) de vuelta a la transacción de BudSound.
async function buscarPorMpPaymentId(mpPaymentId) {
  const { rows } = await pool.query('SELECT * FROM transactions WHERE mp_payment_id = $1', [mpPaymentId]);
  return rows[0] || null;
}

module.exports = { crear, actualizarStatus, buscarPorRequestId, buscarPorMpPaymentId };
