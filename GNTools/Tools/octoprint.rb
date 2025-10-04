require 'net/http'
require 'uri'
require 'json'
require_relative 'GN_websocketGN'

###############################################################
#	
#
#		
#		Classe : GNTools::OctoPrint
#		
#		But :
#			API client pour OctoPrint (serveur de contrôle d’imprimante 3D).
#			Permet d’envoyer des fichiers, des commandes G-code, gérer des impressions et écouter les événements en WebSocket.
#		
#		Attributs :
#		
#			@api_key (String) → Clé API OctoPrint
#		
#			@host (String, readonly via setter) → Adresse serveur OctoPrint (ex: "http://192.168.0.10:5000")
#		
#			@reachable (Bool) → Serveur accessible ?
#		
#			@last_error (String) → Dernière erreur rencontrée
#		
#			@macro1, @macro2, @macro3 (String) → Champs personnalisés pour macros utilisateur
#		
#			@auth (String, interne) → Jeton de session WebSocket
#		
#			@ws (WebSocketGN) → Connexion WebSocket active
#		
#		Fichiers de persistance :
#		
#			Sauvegarde et charge OctoPrintData.txt (clé API, host, macros).
#		
#		Méthodes API principales :
#			🔧 Connexion
#		
#			host=(url) : Définit l’hôte et teste la connectivité.
#		
#			ping(timeout=2) → bool : Vérifie /api/version via HTTP.
#		
#			quick_ping(timeout=1) → bool : Vérifie accessibilité via socket TCP.
#		
#			login_passive → bool : Authentifie via /api/login?passive=true + ouvre WebSocket.
#		
#			closeWebSocket : Ferme proprement la connexion WebSocket.
#		
#		📂 Fichiers
#		
#			upload(file_path, location="local") : Upload fichier G-code.
#		
#			upload_string(content, file_name="virtual.gcode") : Upload un contenu comme fichier.
#		
#			download(file_name, save_path) : Télécharge un fichier.
#		
#			download_string(file_name) : Télécharge et retourne contenu texte.
#		
#			delete_file(file_name) : Supprime un fichier sur OctoPrint.
#		
#			list_files(location="/local") → Array : Liste des fichiers disponibles.
#		
#		🎮 Impression
#		
#			start_print(file_name) : Démarre une impression existante.
#		
#			pause_print / resume_print / cancel_print : Gère job en cours.
#		
#			control_print(action) : Envoie une commande générique (pause, resume, cancel).
#		
#			get_status → Hash : Retourne état du job.
#		
#			printer_status → Hash : Infos globales (températures, état imprimante).
#		
#			connection_Info → Hash : Statut de la connexion imprimante (port série, baudrate).
#		
#			connexion(connect=true) : Connecte/déconnecte l’imprimante.
#		
#		📡 G-code
#		
#			send_gcode(cmd) : Envoie une commande G-code.
#		
#			send_gcodes(multilignes) : Envoie plusieurs lignes de G-code.
#		
#			jog_head(x:, y:, z:, absolute: false, speed: nil) : Déplace les axes manuellement.
#		
#		🔄 Persistance
#		
#			toJson / fromJson : Sérialisation/désérialisation JSON.
#		
#			saveToFile / loadFromFile : Sauvegarde/charge config (clé API, macros).
#		
#		📡 WebSocket
#		
#			handle_ws_message(raw) : Gestion brute des messages reçus.
#		
#		
###############################################################


module GNTools

	class OctoPrint
	  attr_accessor :api_key
	  attr_accessor :last_error
	  attr_reader :host, :reachable
	  attr_accessor :macro1, :macro2, :macro3
	  
	  def initialize(api_key = "", host = "")
		@observers = []
		@api_key = api_key
		self.host = host unless host.empty? # passe par le setter
		@last_error = nil
		@auth = nil
		@reachable = false
		@macro1 = ""
		@macro2 = ""
		@macro3 = ""
		@filename = File.join(GNTools::PATH, "OctoPrintData.txt")
		if File.exist? @filename
			loadFromFile()
		else
#			@api_key = "w3hB9JoyaOEj07EWqCLUbpjrsPtbYXp7cbkw8MqT_x4"
#			@host = "http://10.0.0.108:5000"

			@api_key = ""
			@host = ""
			saveToFile()
		end
	  end

	  def add_observer(&block)
		@observers << block if block
	  end

	  def notify(event, data)
		@observers.each { |o| o.call(event, data) }
	  end
	  
	  # --- Setter personnalisé pour host ---
	  def host=(value)
	    @host = value
	    @reachable = quick_ping
	  end

	  def jog_head(x: nil, y: nil, z: nil, absolute: false, speed: nil)
	    if @reachable
		  uri = URI.parse("#{@host}/api/printer/printhead")

		  request = Net::HTTP::Post.new(uri.request_uri)
		  request["X-Api-Key"] = @api_key
		  request["Content-Type"] = "application/json"

		  body = { command: "jog", absolute: absolute }
		  body[:x] = x if x
		  body[:y] = y if y
		  body[:z] = z if z
		  body[:speed] = speed if speed

		  request.body = body.to_json

		  http = Net::HTTP.new(uri.host, uri.port)
		  response = http.request(request)

#		  puts "Jog -> #{body}"
#		  puts "Response: #{response.code} #{response.body}"
		  notify(:joghead, response)
		  response
	    end
	  end

	  # --- Uploader un fichier G-code ---
	  def upload(file_path, location = "local")
	    if @reachable
		  file_name = File.basename(file_path)
		  uri = URI.parse("#{@host}/api/files/#{@location}")

		  boundary = "----SketchupBoundary#{rand(1000000)}"
		  post_body = []

		  post_body << "--#{boundary}\r\n"
		  post_body << "Content-Disposition: form-data; name=\"file\"; filename=\"#{file_name}\"\r\n"
		  post_body << "Content-Type: application/octet-stream\r\n\r\n"
		  post_body << File.read(file_path)
		  post_body << "\r\n--#{boundary}--\r\n"

		  request = Net::HTTP::Post.new(uri.request_uri)
		  request["X-Api-Key"] = @api_key
		  request["Content-Type"] = "multipart/form-data; boundary=#{boundary}"
		  request.body = post_body.join

		  http = Net::HTTP.new(uri.host, uri.port)
		  response = http.request(request)
		  notify(:upload, response)

#		  puts "Upload: #{response.code} #{response.body}"
		  response
		end
	  end

	  # --- Télécharger un fichier G-code depuis OctoPrint ---
	  def download(file_name, save_path, location = "local")
	    if @reachable
	      uri = URI.parse("#{@host}/downloads/files/#{location}/#{file_name}")

	      request = Net::HTTP::Get.new(uri.request_uri)
	      request["X-Api-Key"] = @api_key

	      http = Net::HTTP.new(uri.host, uri.port)
	      response = http.request(request)

	      if response.code == "200"
	        File.open(save_path, "wb") { |f| f.write(response.body) }
			notify(:download, response)
#		    puts "Fichier téléchargé : #{save_path}"
		    return true
	      else
			notify(:download, response)
#		    puts "Erreur download: #{response.code} #{response.body}"
		    return false
	      end
		end
	  end

	  # --- Lancer impression d’un fichier déjà présent ---
	  def start_print(file_name, location = "local")
	    if @reachable
	      uri = URI.parse("#{@host}/api/files/#{location}/#{file_name}")

	      request = Net::HTTP::Post.new(uri.request_uri)
	      request["X-Api-Key"] = @api_key
	      request["Content-Type"] = "application/json"
	      request.body = { command: "select", print: true }.to_json

	      http = Net::HTTP.new(uri.host, uri.port)
	      response = http.request(request)
		  notify(:start_print, response)
#	      puts "Print: #{response.code} #{response.body}"
	      response
		end
	  end

	  # --- Effacer un fichier sur OctoPrint ---
	  def delete_file(file_name, location = "local")
	    return unless @reachable

	    uri = URI.parse("#{@host}/api/files/#{location}/#{file_name}")

	    request = Net::HTTP::Delete.new(uri.request_uri)
	    request["X-Api-Key"] = @api_key

	    http = Net::HTTP.new(uri.host, uri.port)
	    response = http.request(request)
		notify(:delete_file, response)

	#  puts "Delete: #{response.code} #{response.body}"
	    response
	  end

	  def send_gcodes(textes)
		tabligne = textes.split(/\r\n|\r|\n|#r/)
		tabligne.each do |ligne|
		  self.send_gcode(ligne) unless ligne.strip.empty?
		end
	  end

	  # --- Envoyer une commande G-code directe ---
	  def send_gcode(cmd)
	    if @reachable
	      uri = URI.parse("#{@host}/api/printer/command")

	      request = Net::HTTP::Post.new(uri.request_uri)
	      request["X-Api-Key"] = @api_key
	      request["Content-Type"] = "application/json"
	      request.body = { command: cmd }.to_json

	      http = Net::HTTP.new(uri.host, uri.port)
	      response = http.request(request)
		  notify(:GCodeSend, response)
#	      puts "G-code: #{response.code} #{response.body}"
	      response
		end
	  end

	  # --- Uploader une chaîne comme fichier G-code ---
	  def upload_string(content, file_name = "virtual.gcode", location = "local")
	    if @reachable
	      uri = URI.parse("#{@host}/api/files/#{location}")

	      boundary = "----SketchupBoundary#{rand(1000000)}"
	      post_body = []

	      post_body << "--#{boundary}\r\n"
	      post_body << "Content-Disposition: form-data; name=\"file\"; filename=\"#{file_name}\"\r\n"
	      post_body << "Content-Type: application/octet-stream\r\n\r\n"
	      post_body << content
	      post_body << "\r\n--#{boundary}--\r\n"

	      request = Net::HTTP::Post.new(uri.request_uri)
	      request["X-Api-Key"] = @api_key
	      request["Content-Type"] = "multipart/form-data; boundary=#{boundary}"
	      request.body = post_body.join

	      http = Net::HTTP.new(uri.host, uri.port)
	      response = http.request(request)
		  notify(:upload_string, response)

#	      puts "Upload string: #{response.code} #{response.body}"
	      response
		end
	  end
  
	  # --- Télécharger un fichier G-code et retourner son contenu comme string ---
	  def download_string(file_name, location = "local")
	    if @reachable
	      uri = URI.parse("#{@host}/downloads/files/#{location}/#{file_name}")

	      request = Net::HTTP::Get.new(uri.request_uri)
	      request["X-Api-Key"] = @api_key

	      http = Net::HTTP.new(uri.host, uri.port)
	      response = http.request(request)

	      if response.code == "200"
#	        puts "Download string OK (#{file_name}, taille: #{response.body.size} octets)"
		    notify(:download_string, response)
		    return response.body   # contenu texte du G-code
	      else
#		    puts "Erreur download string: #{response.code} #{response.body}"
		    notify(:download_string, response)
		    return nil
	      end
		end
	  end

	  # --- Pause impression ---
	  def pause_print
	    response = control_print("pause")
		notify(:pause_print, response)
	  end

	  # --- Reprendre impression ---
	  def resume_print
	    response = control_print("resume")
		notify(:resume_print, response)
	  end

	  # --- Annuler impression ---
	  def cancel_print
	    response = control_print("cancel")
		notify(:cancel_print, response)
	  end

	  # --- Obtenir statut impression ---
	  def get_status
	    if @reachable
	      uri = URI.parse("#{@host}/api/job")

	      request = Net::HTTP::Get.new(uri.request_uri)
	      request["X-Api-Key"] = @api_key

	      http = Net::HTTP.new(uri.host, uri.port)
	      response = http.request(request)

	      if response.code == "200"
	        json = JSON.parse(response.body)
		    notify(:print_status, response)
#	  	    puts "Statut: #{json["state"]}, Progression: #{json.dig("progress", "completion")}%"
		    return json
	      else
#		    puts "Erreur status: #{response.code} #{response.body}"
		    notify(:print_status, response)
		    return nil
	      end
		end
	  end

	  def connection_Info
	    if @reachable
	      uri = URI.parse("#{@host}/api/connection")

	      request = Net::HTTP::Get.new(uri.request_uri)
	      request["X-Api-Key"] = @api_key

	      http = Net::HTTP.new(uri.host, uri.port)
	      response = http.request(request)
#		  puts response
	      if response.code == "200"
	        json = JSON.parse(response.body)
		    notify(:connection_info, response)
#	  	    puts "Statut: #{json["state"]}, Progression: #{json.dig("progress", "completion")}%"
		    return json
	      else
		    notify(:connection_info, response)
#		    puts "Erreur status: #{response.code} #{response.body}"
		    return nil
	      end
		end
	  end

	  def connexion(connect = true)
	    if @reachable
	      uri = URI.parse("#{@host}/api/connection")

	      request = Net::HTTP::Post.new(uri.request_uri)
	      request["X-Api-Key"] = @api_key
	      request["Content-Type"] = "application/json"
		  if connect
			request.body = { command: "connect" }.to_json
		  else
			request.body = { command: "disconnect" }.to_json
		  end
	      http = Net::HTTP.new(uri.host, uri.port)
	      response = http.request(request)
		  notify(:connection, response)
		  response
	    end
	  end
	  
	  def control_print(action)
	    if @reachable
	      uri = URI.parse("#{@host}/api/job")

	      request = Net::HTTP::Post.new(uri.request_uri)
	      request["X-Api-Key"] = @api_key
	      request["Content-Type"] = "application/json"
	      request.body = { command: action }.to_json

	      http = Net::HTTP.new(uri.host, uri.port)
	      response = http.request(request)
		  notify(:control_print, response)

#	      puts "#{action.capitalize}: #{response.code} #{response.body}"
	      response
		end
	  end
	  
      # --- Vérifier le statut global de l'imprimante ---
      def printer_status
	    if @reachable
	      uri = URI.parse("#{@host}/api/printer")

	      request = Net::HTTP::Get.new(uri.request_uri)
	      request["X-Api-Key"] = @api_key

	      http = Net::HTTP.new(uri.host, uri.port)
	      response = http.request(request)

	      if response.code == "200"
		    json = JSON.parse(response.body)
		    # Exemple d'information utile
#		    state = json.dig("state", "text")
#		    temperature = json["temperature"]
#		    puts "Printer Status: #{state}"
#		    puts "Temperatures: #{temperature}"
			notify(:printer_status, response)
		    return json
	      else
			notify(:printer_status, response)
#		    puts "Erreur printer_status: #{response.code} #{response.body}"
		    return nil
	      end
		end
	  end

      # --- Lister les fichiers disponibles ---
      def list_files(location = "/local")
	    if @reachable
          uri = URI.parse("#{@host}/api/files#{location}")

          request = Net::HTTP::Get.new(uri.request_uri)
          request["X-Api-Key"] = @api_key
          http = Net::HTTP.new(uri.host, uri.port)
          http.open_timeout = 5   # délai max pour ouvrir la connexion (secondes)
          http.read_timeout = 10  # délai max pour lecture de la réponse

          begin
            response = http.request(request)

            if response.code == "200"
              json = JSON.parse(response.body)
              files = json["files"] || []
			  notify(:list_files, response)
              return files
            else
			  notify(:list_files, response)
#              puts "Erreur list_files: #{response.code} #{response.body}"
              return nil
            end

          rescue SocketError, Errno::ECONNREFUSED => e
			notify(:list_files, e)
#            puts "Erreur réseau: #{e.message}"
            return nil
          rescue Net::OpenTimeout, Net::ReadTimeout => e
		  	notify(:list_files, e)
#            puts "Timeout: #{e.message}"
            return nil
          rescue => e
			notify(:list_files, e)
#            puts "Erreur inconnue: #{e.class} - #{e.message}"
            return nil
          end
#		else
#		  puts "not reachable"
	    end
      end
	  
	  def toJson
		JSON.generate({
				'api_key'  => @api_key,
				'host' => @host,
				'macro1' => @macro1,
				'macro2' => @macro2,
				'macro3' => @macro3
			})		
	  end
	  
	  def fromJson(jsonStr)
		hash = JSON.parse(jsonStr)
		@api_key = hash["api_key"]
		@host = hash["host"]
		@macro1 = hash["macro1"]
		@macro2 = hash["macro2"]
		@macro3 = hash["macro3"]
		@reachable = quick_ping
	  end
	  
	  def saveToFile()
		file = File.open(@filename, "w")
		file.write(toJson())
		file.close
	  end
		
	  def loadFromFile()
		File.foreach(@filename) { |line|
			fromJson(line)
		}
	  end
	  
  	  # --- Tester la connexion (ping OctoPrint) ---
	  def ping(timeout = 2)
	    uri = URI.parse("#{@host}/api/version")
	    request = Net::HTTP::Get.new(uri.request_uri)
	    request["X-Api-Key"] = @api_key

	    http = Net::HTTP.new(uri.host, uri.port)
	    http.open_timeout = timeout   # délai pour ouvrir la connexion
	    http.read_timeout = timeout+1 # délai pour lire la réponse

	    begin
		  response = http.request(request)
		  if response.code.start_with?("2")
		  	notify(:ping, response)
		    return true
		  else
		    @last_error = "HTTP #{response.code}: #{response.body}"
		  	notify(:ping, response)
		    return false
		  end
	    rescue SocketError, Errno::ECONNREFUSED => e
		  @last_error = "Erreur réseau: #{e.message}"
		  notify(:ping, response)
		  return false
	    rescue Net::OpenTimeout, Net::ReadTimeout => e
		  @last_error = "Timeout: #{e.message}"
		  notify(:ping, response)
		  return false
	    rescue => e
		  @last_error = "Erreur inconnue: #{e.class} - #{e.message}"
		  notify(:ping, response)
		  return false
	    end
	  end

  	  # --- Tester la connexion (ping OctoPrint avec Socket) ---	  
	  def quick_ping(timeout = 1)
	    if @host.nil? || @host.empty?
			@reachable = false
			notify(:reachable_changed, @reachable)
			return false
		end
	  	uri = URI.parse(@host)

		begin
		  Socket.tcp(uri.host, uri.port, connect_timeout: timeout) do |sock|
			sock.close
			@reachable = true
			notify(:reachable_changed, @reachable)
			return true
		  end
		  rescue
		  @reachable = false
		  notify(:reachable_changed, @reachable)
		  return false
		end
	  end
	  
	    # --- Login passif (équivalent /api/login?passive=true) ---
	  def login_passive
		return false if @host.nil? || @host.empty?
		uri = URI.parse(@host)
		begin
		  Socket.tcp(uri.host, uri.port, connect_timeout: 1) do |sock|
			sock.close
			@reachable = true
		  end
		  rescue
		  @reachable = false
		  return false
		end

		uri = URI.parse("#{@host}/api/login?passive=true")

		request = Net::HTTP::Post.new(uri.request_uri)
		request["Content-Type"] = "application/json"
		request["X-Api-Key"] = @api_key
		request.body = "{}" # POST vide obligatoire

		http = Net::HTTP.new(uri.host, uri.port)
		response = http.request(request)

		unless response.is_a?(Net::HTTPSuccess)
		  @last_error = "Login failed: #{response.code} #{response.body}"
		  puts "❌ #{@last_error}"
		  notify(:login, response)
		  return nil
		end

		data = JSON.parse(response.body)
		@auth = "#{data["name"]}:#{data["session"]}"
		puts "✅ Login passif réussi: #{@auth}"
		
		# 2. Ouvrir le WebSocket
		ws_url = @host.sub(/^http/, "ws") + "/sockjs/websocket"
		@ws = WebSocketGN.new(ws_url)
		unless @ws.connect
		  puts "❌ Échec connexion WebSocket"
		  notify(:login, response)
		  return false
		end
		puts "✅ Connecté WebSocket"



		# Remplace le thread par un timer SketchUp
		@ws_timer = UI.start_timer(0.1, true) do
		  msg = @ws.recv_text_non_blocking
		  notify(:handle_message, JSON.parse(msg)) if msg
		end
		
		# 3. Envoyer auth
		payload = { auth: @auth }
		@ws.send_text("#{payload.to_json}")
		puts "🔑 Auth envoyé"

		# 4. Abonnement aux événements
		payload = { subscribe: { events: true } }
		@ws.send_text("#{payload.to_json}")
		puts "🔔 Abonnement envoyé"
		
		notify(:login, response)
		return true
	  rescue => e
		@last_error = e.message
		puts "💥 Exception login_passive: #{@last_error}"
		notify(:login, response)
		return false
	  end

	  def handle_ws_message(raw)
	    begin
			data = JSON.parse(raw)
		rescue
			puts "⚠️ Message non-JSON: #{raw}"
			return
		end
		notify(:handle_message, data)
		if data.has_key?("event")
		    type    = data["event"]["type"]
			payload = data["event"]["payload"] || {}
			case type
			  when "Connected"
				puts "🔌 Imprimante connectée"
			  when "Disconnected"
				puts "❌ Imprimante déconnectée"
			  when "PrintStarted"
				puts "▶️ Impression démarrée: #{payload['name']}"
			  when "PrintDone"
				puts "✅ Impression terminée: #{payload['name']}"
			  when "PrintFailed"
				puts "⚠️ Impression échouée: #{payload['name']}"
			  when "UpdatedFiles"
				puts "📂 Fichiers mis à jour"
			  when "Error"
				puts "💥 Erreur: #{payload['error']}"
			  when "PositionUpdate"
				puts "📍 Position: #{payload}"
			else
			  puts "📩 Event: #{type} (#{JSON.pretty_generate(payload)})"
			end
		elsif data.has_key?("connected")
		    puts "✅ Connecté au serveur OctoPrint, version #{data["connected"]["display_version"]}"
		elsif data.has_key?("history")
		    puts "⚠️ History:"
#		    puts "⚠️ History: #{JSON.pretty_generate(data)}"
		elsif data.has_key?("plugin")
			puts "🌡 Plugin: #{data["plugin"]}, données: #{data["data"]}"
		elsif data.has_key?("timelapse")
		    puts "⚠️ Timelapse: #{JSON.pretty_generate(data)}"
		else
			puts "⚠️ Inconnu: #{JSON.pretty_generate(raw)}"
		end
	  end

	  def closeWebSocket
		UI.stop_timer(@ws_timer)
		@ws.close
		notify(:closeSocket, nil)
 	  end
    end  # class OctoPrint
end # method GNTools