"""
Get Let's Encrypt SSL Certificate for app.almedequipments.in
This script helps you get a trusted SSL certificate using certbot

Run this on your EC2 server (Linux) or use certbot directly
"""
import subprocess
import sys
import os

DOMAIN = "app.almedequipments.in"
EMAIL = "your-email@example.com"  # Change this to your email

def check_certbot():
    """Check if certbot is installed"""
    try:
        result = subprocess.run(['certbot', '--version'], capture_output=True, text=True)
        if result.returncode == 0:
            print(f"✓ Certbot found: {result.stdout.strip()}")
            return True
        return False
    except FileNotFoundError:
        return False

def install_certbot_instructions():
    """Print instructions to install certbot"""
    print("\n" + "="*60)
    print("CERTBOT INSTALLATION INSTRUCTIONS")
    print("="*60)
    print("\nFor Ubuntu/Debian EC2:")
    print("  sudo apt-get update")
    print("  sudo apt-get install certbot")
    print("\nFor Amazon Linux 2 EC2:")
    print("  sudo yum install certbot")
    print("\nFor CentOS/RHEL:")
    print("  sudo yum install epel-release")
    print("  sudo yum install certbot")
    print("\n" + "="*60)

def get_certificate():
    """Get Let's Encrypt certificate using certbot"""
    if not check_certbot():
        print("❌ Certbot is not installed")
        install_certbot_instructions()
        print("\nAfter installing certbot, run this script again.")
        return False
    
    print(f"\nGetting Let's Encrypt certificate for {DOMAIN}...")
    print("Make sure:")
    print("  1. Your domain points to this server's IP")
    print("  2. Port 80 is open in your firewall")
    print("  3. Your Flask app is NOT running on port 80 (certbot needs it)")
    print("\nPress Enter to continue or Ctrl+C to cancel...")
    try:
        input()
    except KeyboardInterrupt:
        print("\nCancelled.")
        return False
    
    # Certbot command for standalone mode (requires port 80 to be free)
    cmd = [
        'sudo', 'certbot', 'certonly',
        '--standalone',
        '--preferred-challenges', 'http',
        '-d', DOMAIN,
        '--email', EMAIL,
        '--agree-tos',
        '--non-interactive'
    ]
    
    print(f"\nRunning: {' '.join(cmd)}")
    print("This will temporarily use port 80 to verify domain ownership...")
    
    try:
        result = subprocess.run(cmd, check=True)
        print("\n✓ Certificate obtained successfully!")
        print(f"\nCertificate location:")
        print(f"  Cert: /etc/letsencrypt/live/{DOMAIN}/fullchain.pem")
        print(f"  Key:  /etc/letsencrypt/live/{DOMAIN}/privkey.pem")
        print(f"\nUpdate your config.py:")
        print(f"  SSL_CERT_PATH = '/etc/letsencrypt/live/{DOMAIN}/fullchain.pem'")
        print(f"  SSL_KEY_PATH = '/etc/letsencrypt/live/{DOMAIN}/privkey.pem'")
        return True
    except subprocess.CalledProcessError as e:
        print(f"\n❌ Error getting certificate: {e}")
        print("\nCommon issues:")
        print("  - Domain doesn't point to this server")
        print("  - Port 80 is blocked or in use")
        print("  - Firewall blocking port 80")
        return False
    except Exception as e:
        print(f"\n❌ Error: {e}")
        return False

def renew_certificate():
    """Renew Let's Encrypt certificate"""
    print("\nRenewing certificate...")
    cmd = ['sudo', 'certbot', 'renew']
    try:
        subprocess.run(cmd, check=True)
        print("✓ Certificate renewed (if needed)")
        return True
    except subprocess.CalledProcessError as e:
        print(f"❌ Error renewing: {e}")
        return False

if __name__ == "__main__":
    print("="*60)
    print("Let's Encrypt Certificate Setup")
    print("="*60)
    print(f"\nDomain: {DOMAIN}")
    print(f"Email: {EMAIL}")
    print("\n⚠️  IMPORTANT: Update EMAIL variable in this script!")
    
    if len(sys.argv) > 1 and sys.argv[1] == 'renew':
        renew_certificate()
    else:
        get_certificate()

