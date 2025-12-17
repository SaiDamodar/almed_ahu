"""
Test SSL certificate setup
Run this to verify certificates are valid before starting the Flask app
"""
import ssl
import socket

CERT_PATH = '/etc/letsencrypt/live/app.almedequipments.in/fullchain.pem'
KEY_PATH = '/etc/letsencrypt/live/app.almedequipments.in/privkey.pem'

def test_certificate():
    """Test if SSL certificate is valid"""
    try:
        # Create SSL context
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.load_cert_chain(CERT_PATH, KEY_PATH)
        
        # Create a test socket
        test_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        test_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        test_socket.bind(('127.0.0.1', 8443))
        test_socket.listen(1)
        
        # Try to wrap with SSL
        ssl_socket = context.wrap_socket(test_socket, server_side=True)
        print("✓ SSL certificate is valid and can be loaded")
        
        test_socket.close()
        return True
    except Exception as e:
        print(f"❌ SSL certificate error: {e}")
        return False

if __name__ == "__main__":
    print("Testing SSL certificates...")
    test_certificate()

