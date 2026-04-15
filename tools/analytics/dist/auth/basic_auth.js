import basicAuth from "basic-auth";
import bcrypt from "bcryptjs";
import { pool } from "../db/pool.js";
import { config } from "../config.js";
function unauthorized(res) {
    res.setHeader("WWW-Authenticate", `Basic realm=\"${config.adminAuthRealm}\"`);
    res.status(401).json({ error: "unauthorized" });
}
export async function requireAdminAuth(req, res, next) {
    const credentials = basicAuth(req);
    if (!credentials || !credentials.name || !credentials.pass) {
        unauthorized(res);
        return;
    }
    const userResult = await pool.query("SELECT password_hash FROM admin_users WHERE username = $1", [credentials.name]);
    if (!userResult.rowCount || userResult.rowCount < 1) {
        unauthorized(res);
        return;
    }
    const hash = userResult.rows[0].password_hash;
    const ok = await bcrypt.compare(credentials.pass, hash);
    if (!ok) {
        unauthorized(res);
        return;
    }
    next();
}
