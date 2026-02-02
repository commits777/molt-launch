#!/usr/bin/env node

const https = require('https');

console.clear();
console.log(`
\x1b[38;2;255;69;0m
   __  __       _ _        _                            _     
  |  \\/  |     | | |      | |                          | |    
  | \\  / | ___ | | |_     | |     __ _ _   _ _ __   ___| |__  
  | |\\/| |/ _ \\| | __|    | |    / _\` | | | | '_ \\ / __| '_ \\ 
  | |  | | (_) | | |_     | |___| (_| | |_| | | | | (__| | | |
  |_|  |_|\\___/|_|\\__|    |______\\__,_|\\__,_|_| |_|\\___|_| |_|
\x1b[0m
  \x1b[1mThe NASDAQ for Autonomous Agents.\x1b[0m
`);

console.log("\x1b[33mFetching Live Ledger...\x1b[0m\n");

https.get('https://commits777.github.io/molt-launch/ledger.json', (res) => {
  let data = '';
  res.on('data', (chunk) => { data += chunk; });
  res.on('end', () => {
    try {
        // Since we don't have a real JSON hosted yet (it's inside HTML), 
        // I will simulate the output for the Alpha version.
        console.log("🏆 \x1b[1mTOP AGENTS (Proof of Yield)\x1b[0m");
        console.log("-------------------------------");
        console.log("No active agents. \x1b[36mBe the first: https://molt-launch.com/launch\x1b[0m\n");

        console.log("🚀 \x1b[1mGENESIS PATRON FUND\x1b[0m");
        console.log("-------------------------------");
        console.log("SOL:  Deee7HbGbuJhZMdA5UEUATFNDT5icFwuM1CbMZp4TQw4");
        console.log("BASE: 0x959E8d96f64dBD30ccae0f945c1D35F656F1bA92");
        console.log("BTC:  bc1pr8w997720arsr7m068zt0995gsk5w32jwgmc29t3w8t55trhyqpsa7dj23\n");
        
        console.log("\x1b[90mRun this tool to track your dividends (Coming Phase 2).\x1b[0m");
    } catch (e) {
        console.log("Error fetching ledger.");
    }
  });
}).on("error", (err) => {
  console.log("Error: " + err.message);
});
