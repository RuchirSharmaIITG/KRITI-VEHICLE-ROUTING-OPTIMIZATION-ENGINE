const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');

const app = express();
const PORT = 3000;

// Middleware
app.use(cors()); // Allows your mobile app to connect without security blocks
app.use(body-parser.json()); // Parses the JSON input from your app

// This is where your custom logic goes
function processInput(userInput) {
    // Example: Converting input to uppercase or doing a calculation
    return {
        message: "Data received successfully!",
        originalData: userInput,
        processedData: `Server says: ${userInput.toUpperCase()}`,
        timestamp: new Date().toISOString()
    };
}

// The API endpoint your mobile app will call
app.post('/api/input', (req, res) => {
    const dataFromApp = req.body.input; // Assuming your app sends { "input": "..." }

    console.log("Received from mobile:", dataFromApp);

    if (!dataFromApp) {
        return res.status(400).json({ error: "No input provided" });
    }

    // Process the data and get the output
    const output = processInput(dataFromApp);

    // Send the JSON output back to the mobile app
    res.json(output);
});

// Start the server
app.listen(PORT, '0.0.0.0', () => {
    console.log(` Server is running!`);
    console.log(`Connect via USB and run: adb reverse tcp:${PORT} tcp:${PORT}`);
    console.log(`Your App should point to: http://127.0.0.1:${PORT}/api/input`);
});