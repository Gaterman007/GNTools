#######################################################################################
#			
#		Classe : GNTools::WebSocketGN
#			
#		But :
#			Gérer une connexion WebSocket brute (sans dépendance externe) pour communiquer avec OctoPrint (ou tout autre serveur WebSocket).
#			
#		Attributs :
#			
#			@url (String, readonly) → URL du serveur WebSocket (ex: "ws://192.168.0.10:5000/sockjs/websocket")
#			
#			@host (String, readonly) → Nom d’hôte extrait de l’URL
#			
#			@port (Integer, readonly) → Port du serveur
#			
#			@path (String, readonly) → Chemin du socket (par défaut /)
#			
#			@sock (TCPSocket, readonly) → Socket TCP ouvert
#			
#		Méthodes principales :
#			
#			initialize(url)
#			Crée une instance et prépare l’URL/host/port/path, mais ne connecte pas encore.
#			
#			connect → true|raise
#			Établit la connexion TCP et effectue le handshake WebSocket.
#			Lève une exception si la négociation échoue.
#			
#			send_text(msg)
#			Envoie une frame texte WebSocket avec masquage client.
#			
#			recv_text → String|nil
#			Lit une frame bloquante. Retourne nil si ce n’est pas du texte.
#			
#			recv_text_non_blocking → String|nil
#			Vérifie rapidement (100 ms timeout) s’il y a un message en attente.
#			
#			close
#			Ferme la socket si ouverte.
#			
#######################################################################################

module GNTools
	class WebSocketGN
	  attr_reader :sock, :url, :host, :port, :path

	  def initialize(url)
		@url  = url
		uri   = URI.parse(url)
		@host = uri.host
		@port = uri.port || 80
		@path = uri.path.empty? ? "/" : uri.path
		@sock = nil
	  end

	  # --- Etape 1 : Handshake HTTP Upgrade ---
	  def connect
		@sock = TCPSocket.new(@host, @port)
		key   = Base64.strict_encode64(SecureRandom.random_bytes(16))

		req = [
		  "GET #{@path} HTTP/1.1",
		  "Host: #{@host}:#{@port}",
		  "Upgrade: websocket",
		  "Connection: Upgrade",
		  "Sec-WebSocket-Key: #{key}",
		  "Sec-WebSocket-Version: 13",
		  "\r\n"
		].join("\r\n")

		@sock.write(req)

		response = @sock.readpartial(1024)
		unless response.include?("101 Switching Protocols")
		  raise "WebSocket handshake failed: #{response}"
		end

		true
	  end

	  # --- Etape 2 : Envoyer une frame texte ---
	  def send_text(msg)
		frame = []
		bytes = msg.bytes
		length = bytes.size

		# FIN=1, opcode=1 (texte)
		frame << 0x81

		if length <= 125
		  frame << (0x80 | length)
		elsif length < 65536
		  frame << (0x80 | 126)
		  frame += [length].pack("n").bytes
		else
		  frame << (0x80 | 127)
		  frame += [length].pack("Q>").bytes
		end

		# masking key (obligatoire côté client)
		mask = Array.new(4) { rand(256) }
		frame += mask

		# appliquer masque
		masked = bytes.each_with_index.map { |b, i| b ^ mask[i % 4] }
		frame += masked

		@sock.write(frame.pack("C*"))
	  end

	  # --- Etape 3 : Lire une frame texte ---
	  def recv_text
		first_byte = @sock.read(1)&.ord
		return nil unless first_byte
		second_byte = @sock.read(1).ord

		fin     = (first_byte & 0x80) != 0
		opcode  = first_byte & 0x0f
		masked  = (second_byte & 0x80) != 0
		length  = (second_byte & 0x7f)

		if length == 126
		  length = @sock.read(2).unpack1("n")
		elsif length == 127
		  length = @sock.read(8).unpack1("Q>")
		end

		mask = masked ? @sock.read(4).bytes : nil
		payload = @sock.read(length).bytes

		if masked
		  payload = payload.each_with_index.map { |b, i| b ^ mask[i % 4] }
		end

		data = payload.pack("C*")
		return data if opcode == 1 # texte
		nil
	  end

	  def recv_text_non_blocking
		ready = IO.select([@sock], nil, nil, 0.1) # 100ms timeout
		return nil unless ready
		recv_text
	  end

	  def close
		@sock.close if @sock
		@sock = nil
	  end
	end
end