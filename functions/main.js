
const stripe = require('stripe')(functions.config().stripe.testkey)

exports.StripePI = functions.https.onRequest(async (req, res) => {  res.send('error');});