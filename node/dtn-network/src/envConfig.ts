import fs from 'fs';
import dotenv from 'dotenv';
const envFiles = ['.env', '.env.production', './localConfig/.env'];
let envLoaded = false;

for (const envFile of envFiles) {
    if (fs.existsSync(envFile)) {
        dotenv.config({ path: envFile });
        console.log(`📄 Loaded environment from: ${envFile}`);
        envLoaded = true;
        console.log(`📄 Loaded environment: ${process.env}`);
        break;
    }
}

if (!envLoaded) {
    console.warn('⚠️  No environment file found. Tried:', envFiles.join(', '));
}