const functions = require("firebase-functions")
const stripe = require('stripe')("**")

exports.StripePI = functions.https.onRequest(async (req, res) => {
  let paymentMethod = await stripe.paymentMethods.create(
    {
      payment_method:req.body.paym,
    },
    
  )
  await stripe.paymentIntents.create(
    {
      amount: req.body.amount,
      currency: req.body.currency,
      payment_method: paymentMethod.id,
      confirmation_method: 'automatic',
      confirm: true,
      application_fee_amount: 1,
      description: req.body.description,
    },
  );

})
  