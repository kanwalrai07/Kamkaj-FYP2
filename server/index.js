require('dotenv').config();
const express = require('express');
const { createClient } = require('@supabase/supabase-js');
const cors = require('cors');
const helmet = require('helmet');
const { body, validationResult } = require('express-validator');

const app = express();
const port = process.env.PORT || 3000;

// Middleware
app.use(helmet());
app.use(cors());
app.use(express.json());

// Initialize Supabase
const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_KEY;
const supabase = createClient(supabaseUrl, supabaseKey);

// --- Admin API Endpoints ---

// 1. Get all pending CNIC verifications
app.get('/api/admin/cnic-pending', async (req, res) => {
    try {
        const { data, error } = await supabase
            .from('cnic_verifications')
            .select('*')
            .eq('status', 'pending');

        if (error) throw error;
        res.json(data);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// 2. Review CNIC (Approve/Reject)
app.post('/api/admin/verify-worker', [
    body('workerId').notEmpty(),
    body('status').isIn(['approved', 'rejected']),
], async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
        return res.status(400).json({ errors: errors.array() });
    }

    const { workerId, status, reason } = req.body;

    try {
        const { data, error } = await supabase
            .from('cnic_verifications')
            .update({ status, reviewed_at: new Date(), rejection_reason: reason })
            .eq('worker_id', workerId);

        if (error) throw error;

        // In a real app, you would also update the Firebase user status here
        // or trigger a webhook.
        
        res.json({ message: `Worker ${workerId} verification ${status}`, data });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// 3. Ustaad Score Algorithm (Backend Implementation)
// This fulfills requirement 8.4 and 11.2 (API response time)
app.get('/api/worker/:id/ustaad-score', async (req, res) => {
    const { id } = req.params;
    
    try {
        // Mocking database fetch for ratings
        // In reality, you'd fetch from Supabase 'reviews' table
        const { data: reviews, error } = await supabase
            .from('reviews')
            .select('rating')
            .eq('worker_id', id);

        if (error) throw error;

        const count = reviews.length;
        const avgRating = count > 0 
            ? reviews.reduce((acc, r) => acc + r.rating, 0) / count 
            : 5.0;

        // Ustaad Score Logic: (Rating * 0.8) + (Min(Jobs/10, 1.0) * 1.0)
        const experienceBonus = Math.min(count / 10, 1.0);
        const ustaadScore = (avgRating * 0.8) + experienceBonus;

        res.json({
            worker_id: id,
            rating: avgRating.toFixed(2),
            jobs_completed: count,
            ustaad_score: ustaadScore.toFixed(2)
        });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Health check
app.get('/health', (req, res) => {
    res.json({ status: 'ok', timestamp: new Date() });
});

app.listen(port, () => {
    console.log(`KamKaj Admin API listening at http://localhost:${port}`);
});
