import { exec } from "child_process";

export function getEarnAppStatus() {
  return new Promise((resolve, reject) => {
    exec("systemctl is-active earnapp", (err, stdout) => {
      if (err) return resolve("inactive");
      resolve(stdout.trim());
    });
  });
}

export function restartEarnApp() {
  return new Promise((resolve, reject) => {
    exec("systemctl restart earnapp", (err) => {
      if (err) return reject(err);
      resolve();
    });
  });
}
