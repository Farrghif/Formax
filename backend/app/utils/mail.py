import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

SMTP_SERVER = "smtp.gmail.com"
SMTP_PORT = 587
SENDER_EMAIL = "formax.support@gmail.com"
APP_PASSWORD = "duea yiju iblv ljgz"  # This is usually kept in .env, but hardcoding for now as requested

def send_otp_email(recipient_email: str, otp_code: str):
    msg = MIMEMultipart()
    msg["From"] = SENDER_EMAIL
    msg["To"] = recipient_email
    msg["Subject"] = "Form4x - Kode Verifikasi Anda"

    body = f"""
    Halo,
    
    Berikut adalah kode verifikasi (OTP) untuk aplikasi Form4x Anda:
    
    {otp_code}
    
    Kode ini hanya berlaku selama 5 menit. Tolong jangan bagikan kode ini kepada siapapun.
    
    Salam,
    Tim Form4x
    """
    
    msg.attach(MIMEText(body, "plain"))

    try:
        server = smtplib.SMTP(SMTP_SERVER, SMTP_PORT)
        server.starttls()
        server.login(SENDER_EMAIL, APP_PASSWORD)
        server.send_message(msg)
        server.quit()
        return True
    except Exception as e:
        print(f"Failed to send email: {e}")
        return False
