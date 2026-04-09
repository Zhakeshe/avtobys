const path = require("path");

/** PM2: серверде backend қалтасынан іске қосыңыз: pm2 start ecosystem.config.cjs */
module.exports = {
  apps: [
    {
      name: "avtobys-backend",
      script: path.join(__dirname, "server.js"),
      cwd: __dirname,
      instances: 1,
      exec_mode: "fork",
      autorestart: true,
      max_memory_restart: "500M",
      env: {
        NODE_ENV: "production",
      },
    },
  ],
};
