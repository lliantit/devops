const express = require('express');
const mongoose = require('mongoose');

const app = express();
app.use(express.json());

const mongoUri = process.env.MONGO_URI || 'mongodb://localhost:27017/delivery';
mongoose.connect(mongoUri)
    .then(() => console.log('Connected to DB'))
    .catch(err => console.error('DB connection error:', err));

const Order = mongoose.model('Order', { item: String, address: String, status: String });

app.post('/orders', async (req, res) => {
    const order = new Order({ ...req.body, status: 'created' });
    await order.save();
    res.status(201).json(order);
});

app.get('/health', (req, res) => {
    res.status(200).json({ status: 'OK' });
});

if (require.main === module) {
    const port = process.env.PORT || 3000;
    app.listen(port, () => console.log(`Server running on port ${port}`));
}

module.exports = app;