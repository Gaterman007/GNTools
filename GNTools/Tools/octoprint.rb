require 'net/http'
require 'uri'
require 'json'

###############################################################
#	
#		class OctoPrint
#				accessor 	api_key
#	  			accessor 	last_error
#	  		    read only 	host
#							reachable
#
#				--- initialize avec api key et host si fichier exist alors aller chercher du fichier ---
#				initialize(api_key = "", host = "")
#
#				--- Setter personnalisé pour host ---
#				host=(value)
#
#				--- Uploader un fichier G-code a OctoPrint ---
#				upload(file_path, location = "local")									/api/files/#{location}
#
#				--- Télécharger un fichier G-code depuis OctoPrint ---
#				download(file_name, save_path, location = "local")						/downloads/files/#{location}
#
#				--- Lancer impression d’un fichier déjà présent ---
#				start_print(file_name)													/api/files/local/
#
#				--- Envoyer une commande G-code directe ---
#				send_gcode(cmd)															/api/printer/command
#
#				--- Uploader une chaîne comme fichier G-code ---
#				upload_string(content, file_name = "virtual.gcode", location = "local")	/api/files/#{location}
#
#				--- Télécharger un fichier G-code et retourner son contenu comme string ---
#				download_string(file_name, location = "local")												/downloads/files/local/#{file_name}
#
#				--- envoyer les commandes de pause/resume ou cancel de job ---
#				pause_print
#				resume_print
#				cancel_print
#
#				--- Obtenir statut impression ---
#				get_status																/api/job
#
#				--- envoyer un action pour job ---
#				control_print(action)													/api/job
#
#				--- Vérifier le statut global de l'imprimante ---
#				printer_status															/api/printer
#
#				--- Lister les fichiers disponibles ---
#				list_files(location = "local")											/api/files/#{location}
#
#				--- api key et host ---
#				toJson
#				fromJson(jsonStr)
#				saveToFile()
#				loadFromFile()
#
#				--- Tester la connexion (ping OctoPrint avec Get) ---
#				ping(timeout = 2)														/api/version
#
#				--- Tester la connexion (ping OctoPrint avec Socket) ---
#				quick_ping(timeout = 1)
#
###############################################################


module GNTools
	class OctoPrint
	  attr_accessor :api_key
	  attr_accessor :last_error
	  attr_reader :host, :reachable
	  
	  def initialize(api_key = "", host = "")
		@api_key = api_key
		self.host = host unless host.empty? # passe par le setter
		@last_error = nil
		@reachable = false
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
#		    puts "Fichier téléchargé : #{save_path}"
		    return true
	      else
#		    puts "Erreur download: #{response.code} #{response.body}"
		    return false
	      end
		end
	  end

	  # --- Lancer impression d’un fichier déjà présent ---
	  def start_print(file_name)
	    if @reachable
	      uri = URI.parse("#{@host}/api/files/local/#{file_name}")

	      request = Net::HTTP::Post.new(uri.request_uri)
	      request["X-Api-Key"] = @api_key
	      request["Content-Type"] = "application/json"
	      request.body = { command: "select", print: true }.to_json

	      http = Net::HTTP.new(uri.host, uri.port)
	      response = http.request(request)

#	      puts "Print: #{response.code} #{response.body}"
	      response
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
		    return response.body   # contenu texte du G-code
	      else
#		    puts "Erreur download string: #{response.code} #{response.body}"
		    return nil
	      end
		end
	  end

	  # --- Pause impression ---
	  def pause_print
	    control_print("pause")
	  end

	  # --- Reprendre impression ---
	  def resume_print
	    control_print("resume")
	  end

	  # --- Annuler impression ---
	  def cancel_print
	    control_print("cancel")
	  end

	  # --- Obtenir statut impression ---
	  def get_status
	    if quick_ping()
	      uri = URI.parse("#{@host}/api/job")

	      request = Net::HTTP::Get.new(uri.request_uri)
	      request["X-Api-Key"] = @api_key

	      http = Net::HTTP.new(uri.host, uri.port)
	      response = http.request(request)

	      if response.code == "200"
	        json = JSON.parse(response.body)
#	  	    puts "Statut: #{json["state"]}, Progression: #{json.dig("progress", "completion")}%"
		    return json
	      else
#		    puts "Erreur status: #{response.code} #{response.body}"
		    return nil
	      end
		end
	  end

	  def control_print(action)
	    if quick_ping()
	      uri = URI.parse("#{@host}/api/job")

	      request = Net::HTTP::Post.new(uri.request_uri)
	      request["X-Api-Key"] = @api_key
	      request["Content-Type"] = "application/json"
	      request.body = { command: action }.to_json

	      http = Net::HTTP.new(uri.host, uri.port)
	      response = http.request(request)

#	      puts "#{action.capitalize}: #{response.code} #{response.body}"
	      response
		end
	  end
	  
      # --- Vérifier le statut global de l'imprimante ---
      def printer_status
	    if quick_ping()
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
		    return json
	      else
#		    puts "Erreur printer_status: #{response.code} #{response.body}"
		    return nil
	      end
		end
	  end

      # --- Lister les fichiers disponibles ---
      def list_files(location = "local")
	    if @reachable
          uri = URI.parse("#{@host}/api/files/#{location}")

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
              return files
            else
#              puts "Erreur list_files: #{response.code} #{response.body}"
              return nil
            end

          rescue SocketError, Errno::ECONNREFUSED => e
#            puts "Erreur réseau: #{e.message}"
            return nil
          rescue Net::OpenTimeout, Net::ReadTimeout => e
#            puts "Timeout: #{e.message}"
            return nil
          rescue => e
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
				'host' => @host
			})		
	  end
	  
	  def fromJson(jsonStr)
		hash = JSON.parse(jsonStr)
		@api_key = hash["api_key"]
		@host = hash["host"]
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
		    return true
		  else
		    @last_error = "HTTP #{response.code}: #{response.body}"
		    return false
		  end
	    rescue SocketError, Errno::ECONNREFUSED => e
		  @last_error = "Erreur réseau: #{e.message}"
		  return false
	    rescue Net::OpenTimeout, Net::ReadTimeout => e
		  @last_error = "Timeout: #{e.message}"
		  return false
	    rescue => e
		  @last_error = "Erreur inconnue: #{e.class} - #{e.message}"
		  return false
	    end
	  end

  	  # --- Tester la connexion (ping OctoPrint avec Socket) ---	  
	  def quick_ping(timeout = 1)
		return false if @host.nil? || @host.empty?
		uri = URI.parse(@host)

		begin
		  Socket.tcp(uri.host, uri.port, connect_timeout: timeout) do |sock|
			sock.close
			return true
		  end
		  rescue
		  return false
		end
	  end
    end  # class OctoPrint
end # method GNTools