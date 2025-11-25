"""
Generate SSL certificates for app.almedequipments.in
Run this script on Windows to generate certificate and key files
"""
from cryptography import x509
from cryptography.x509.oid import NameOID
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from datetime import datetime, timedelta
import os

# Certificate details
DOMAIN = "app.almedequipments.in"
CERT_FILE = "cert.pem"
KEY_FILE = "key.pem"

def generate_certificate():
    """Generate self-signed SSL certificate"""
    print(f"Generating SSL certificate for {DOMAIN}...")
    
    # Generate private key
    print("Generating private key...")
    private_key = rsa.generate_private_key(
        public_exponent=65537,
        key_size=2048,
    )
    
    # Create certificate
    print("Creating certificate...")
    subject = issuer = x509.Name([
        x509.NameAttribute(NameOID.COUNTRY_NAME, "IN"),
        x509.NameAttribute(NameOID.STATE_OR_PROVINCE_NAME, "Maharashtra"),
        x509.NameAttribute(NameOID.LOCALITY_NAME, "Mumbai"),
        x509.NameAttribute(NameOID.ORGANIZATION_NAME, "ALMED Equipments"),
        x509.NameAttribute(NameOID.COMMON_NAME, DOMAIN),
    ])
    
    cert = x509.CertificateBuilder().subject_name(
        subject
    ).issuer_name(
        issuer
    ).public_key(
        private_key.public_key()
    ).serial_number(
        x509.random_serial_number()
    ).not_valid_before(
        datetime.utcnow()
    ).not_valid_after(
        datetime.utcnow() + timedelta(days=365)
    ).add_extension(
        x509.SubjectAlternativeName([
            x509.DNSName(DOMAIN),
            x509.DNSName(f"*.{DOMAIN}"),
        ]),
        critical=False,
    ).sign(private_key, hashes.SHA256())
    
    # Write certificate to file
    print(f"Writing certificate to {CERT_FILE}...")
    with open(CERT_FILE, "wb") as f:
        f.write(cert.public_bytes(serialization.Encoding.PEM))
    
    # Write private key to file
    print(f"Writing private key to {KEY_FILE}...")
    with open(KEY_FILE, "wb") as f:
        f.write(private_key.private_bytes(
            encoding=serialization.Encoding.PEM,
            format=serialization.PrivateFormat.PKCS8,
            encryption_algorithm=serialization.NoEncryption()
        ))
    
    print("\n✓ Certificate and key generated successfully!")
    print(f"  Certificate: {CERT_FILE}")
    print(f"  Private Key: {KEY_FILE}")
    print("\n⚠️  Note: This is a self-signed certificate.")
    print("   For production, consider using Let's Encrypt (certbot) for a trusted certificate.")

if __name__ == "__main__":
    try:
        generate_certificate()
    except Exception as e:
        print(f"\n❌ Error generating certificate: {e}")
        print("\nMake sure you have cryptography installed:")
        print("  pip install cryptography")
        exit(1)

