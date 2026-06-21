<%@ WebHandler Language="C#" Class="SaveExcel" %>
using System;
using System.IO;
using System.Web;

public class SaveExcel : IHttpHandler {

    public void ProcessRequest(HttpContext context) {
        context.Response.ContentType = "application/json";
        context.Response.Cache.SetNoStore();

        /* รับเฉพาะ POST */
        if (!string.Equals(context.Request.HttpMethod, "POST", StringComparison.OrdinalIgnoreCase)) {
            context.Response.StatusCode = 405;
            context.Response.Write("{\"ok\":false,\"error\":\"Method not allowed\"}");
            return;
        }

        try {
            /* อิงโฟลเดอร์ของ handler เอง (/0_api/) ไม่ใช่ root ของ application
               MapPath ด้วย path สัมพัทธ์ = โฟลเดอร์ของไฟล์ที่ถูกเรียก */
            string srcFile   = context.Server.MapPath("API_Team.xlsx");
            string backupDir = context.Server.MapPath("Backup");
            string backupName = "";

            /* สร้างโฟลเดอร์ Backup ถ้ายังไม่มี */
            if (!Directory.Exists(backupDir))
                Directory.CreateDirectory(backupDir);

            /* ย้ายไฟล์เดิมไป Backup ก่อน (ถ้ามี) */
            if (File.Exists(srcFile)) {
                string ts = DateTime.Now.ToString("yyyyMMdd_HHmmss");
                backupName = string.Format("API_Team_{0}.xlsx", ts);
                string backupPath = Path.Combine(backupDir, backupName);

                /* ป้องกันชื่อซ้ำ (กรณีบันทึกถี่มาก) */
                int seq = 1;
                while (File.Exists(backupPath)) {
                    backupName = string.Format("API_Team_{0}_{1}.xlsx", ts, seq++);
                    backupPath = Path.Combine(backupDir, backupName);
                }

                File.Move(srcFile, backupPath);
            }

            /* บันทึกไฟล์ใหม่ทับตำแหน่งเดิม (อ่าน stream แบบ loop รองรับ .NET ทุกเวอร์ชัน) */
            using (MemoryStream ms = new MemoryStream()) {
                Stream input = context.Request.InputStream;
                byte[] buffer = new byte[8192];
                int read;
                while ((read = input.Read(buffer, 0, buffer.Length)) > 0) {
                    ms.Write(buffer, 0, read);
                }
                byte[] data = ms.ToArray();
                if (data.Length == 0) throw new Exception("empty body");
                File.WriteAllBytes(srcFile, data);
            }

            context.Response.StatusCode = 200;
            context.Response.Write(string.Format(
                "{{\"ok\":true,\"backup\":\"{0}\"}}",
                backupName.Replace("\"", "\\\"")
            ));
        }
        catch (Exception ex) {
            context.Response.StatusCode = 500;
            context.Response.Write(string.Format(
                "{{\"ok\":false,\"error\":\"{0}\"}}",
                ex.Message.Replace("\"", "\\\"").Replace("\n", " ")
            ));
        }
    }

    public bool IsReusable { get { return false; } }
}
