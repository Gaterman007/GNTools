module GNTools
  module NewPaths

    class StrategyEngine

      DEFAULT = {
        "contour" => <<~STRAT,
          ; --- Strategy: contour ---
          G0 X{points[0].x} Y{points[0].y} Z{safeHeight}
          {foreach p in points}
            G1 X{p.x} Y{p.y} F{feedrate}
          {end}
          G1 Z{safeHeight}
       STRAT

        "drill" => <<~STRAT,
          ; --- Strategy: drill ---
          G0 X{points[0].x} Y{points[0].y} Z{safeHeight}
          G1 Z{depth} F{feedrate}
          G0 Z{safeHeight}
        STRAT
		
		"Hole" => <<~STRAT,
          ; --- Strategy: Hole ---
          G0 X{points[0].x} Y{points[0].y} Z{safeHeight} F{feedrate}
          G1 Z{depth} F{feedrate}
          G0 Z{safeHeight}
        STRAT
		
		"Line" => <<~STRAT,
          ; --- Strategy: Line ---
          G0 X{points[0].x} Y{points[0].y} Z{safeHeight} F{feedrate}
          G1 Z{depth} F{feedrate}
          G0 Z{safeHeight}
        STRAT
      }
    
	  attr_accessor:strategies
	  attr_accessor :global_vars

      def self.instance
        @instance ||= new
      end
	
      def initialize()
        @toolpath = nil
		@strategies = load_all_strategies
		@global_vars = {}
      end

      # ============================================================
      # Récupérer une stratégie (base + custom)
      # ============================================================
      def get(name)
        @strategies[name] or raise "Strategy '#{name}' not found"
      end

      # ============================================================
      # Ajouter ou modifier une stratégie à chaud
      # ============================================================
      def set(name, text)
        @strategies[name] = text
        save_custom_strategies
      end

      # ============================================================
      # Générer le G-code à partir d’une stratégie
      # ============================================================
      def render(name,toolpath,vars = nil)
	    # Merge : global < local
		@vars = @global_vars.dup
		@vars.merge!(vars) if vars
		@toolpath = toolpath["Toolpath"]
        @text = get(name).dup
		process_foreach!
		process_if!
		process_vars!
        @text
      end

      # ============================================================
      # Chargements
      # ============================================================
      def load_all_strategies
        base = DEFAULT.dup
        custom = load_custom_file
        base.merge(custom)
      end

      def load_custom_file
        file = File.join(GNTools::PATH_TOOLS, "Strategies.custom")
        return {} unless File.exist?(file)

        text = File.read(file)
        parse_custom_strategies(text)
      end
      # ============================================================
      # Sauvegarde
      # ============================================================
      def save_custom_strategies
        file = File.join(GNTools::PATH_TOOLS, "Strategies.custom")

        File.open(file, "w") do |f|
          @strategies.each do |name, text|
            next if GNTools::NewPaths::StrategyEngine::DEFAULT[name] == text # évite les doublons
            f.puts "[strategy #{name}]"
            f.puts text
            f.puts
          end
        end
      end

      # ============================================================
      # Parsing du fichier custom
      # ============================================================
      def parse_custom_strategies(text)
        h = {}
        current = nil
        buffer = []

        text.each_line do |line|
          if line =~ /^\[strategy (.+?)\]/
            h[current] = buffer.join if current
            current = $1.strip
            buffer = []
          elsif current
            buffer << line
          end
        end

        h[current] = buffer.join if current
        h
      end

	  def process_if!
	    @text.gsub!(/\{if (.+?)\}(.*?)\{end\}/m) do
		  condition = $1.strip
		  block = $2

		  result = eval_condition(condition)
		  result ? block : ""
	    end
	  end

	  def eval_condition(cond)
	    # Si c'est une comparaison : var > 0, x == y, etc.
	    if cond =~ /(.+?)\s*(==|!=|>=|<=|>|<)\s*(.+)/
		  left_expr  = $1.strip
		  operator   = $2
		  right_expr = $3.strip

		  left_val  = eval_in_schema(left_expr)
		  right_val = eval_in_schema(right_expr)

		  # conversion numérique si possible
		  left_val  = numeric_or_string(left_val)
		  right_val = numeric_or_string(right_val)

		  case operator
		  when "==" then left_val == right_val
		  when "!=" then left_val != right_val
		  when ">"  then left_val >  right_val
		  when "<"  then left_val <  right_val
		  when ">=" then left_val >= right_val
		  when "<=" then left_val <= right_val
		  else false
		  end

	    else
		  # Cas booléen simple : {if enabled}
		  val = eval_in_schema(cond)
		  boolize(val)
	    end
	  end

	  def numeric_or_string(v)
	    Float(v) rescue v
	  end

	  def boolize(v)
	    return true if v == true || v.to_s.downcase == "true" || v.to_s == "1"
	    return false
	  end

      # ============================================================
      # Traitement {foreach}
      # ============================================================
      def process_foreach!
        @text.gsub!(/\{foreach ([a-zA-Z0-9_]+) in ([a-zA-Z0-9_]+)\}(.*?)\{end\}/m) do
          item_name = $1
          array_name = $2
          block = $3
	
		  if @toolpath
			if array_name == "points"
			  point_array = @toolpath["points"]
			  point_array.map do |item|
			    b = block.dup
				b.gsub!(/\{#{item_name}\.x\}/, item.position.x.round(2).to_s)
				b.gsub!(/\{#{item_name}\.y\}/, item.position.y.round(2).to_s)
				b.gsub!(/\{#{item_name}\.z\}/, item.position.z.round(2).to_s)				
				b
			  end
			else
			  array = @toolpath["metadata"][array_name]
			  raise "Missing array #{array_name}" unless array.is_a?(Array)

			  array.map do |item|
			    b = block.dup
			    b.gsub!(/\{#{item_name}\}/, item.to_s)
			    if item.respond_to?(:x)
				  b.gsub!(/\{#{item_name}\.x\}/, item.x.round(2).to_s)
				  b.gsub!(/\{#{item_name}\.y\}/, item.y.round(2).to_s)
				  b.gsub!(/\{#{item_name}\.z\}/, item.z.round(2).to_s) if item.respond_to?(:z)
			    end
			    b
			  end
			end.join("\n")
		  end
        end
      end

      # ============================================================
      # Traitement des variables simples {var}
      # ============================================================
      def process_vars!
        @text.gsub!(/\{([a-zA-Z0-9_\.\[\]]+)\}/) do
          eval_in_schema($1)
        end
      end


      def eval_in_schema(expr)
		return expr unless @toolpath

	    # 0 — variables globales / locales
	    if @vars && @vars.key?(expr)
		  v = @vars[expr]
		  return v.is_a?(Numeric) ? v.round(2).to_s : v.to_s
	    end

	    # 1 — Séparer base et attribut (ex : "points[0]" + "x")
	    if expr.include?(".")
		  base, attr = expr.split(".", 2)
	    else
		  base = expr
		  attr = nil
	    end

	    # 2 — Détecter accès tableau : pts[0]
	    if base =~ /(\w+)\[(\d+)\]/
		  key   = $1
		  index = $2.to_i
		  # Cas spécial : points[]
		  if key == "points"
			pt = @toolpath["points"][index]["pos"]

			if attr # points[0].x / .y / .z
			  case attr
			  when "x" then return pt.x.round(2).to_s
			  when "y" then return pt.y.round(2).to_s
			  when "z" then return pt.z.round(2).to_s
			  else
				raise "Invalid attribute #{attr} for points[]"
			  end
			else
			  # points[0] sans . → full XYZ
			  return pt.position_to_string
			end
		  end

		  # Autres tableaux (ex : feeds[1], speeds[2]…)
		  arr = @toolpath[key]

		  value = arr.is_a?(Array) ? arr[index] : arr
		  return attr ? extract_attr(value, attr) : value.to_s
	    end

		# 3 — Variable toolpath : feedrate, speed, tool, etc.
		value = @toolpath["metadata"][base]
		if value != nil
			value = value["Value"]
			if not value.is_a?(String)
			  return value.round(2).to_s
			end
			return value.to_s
		else
			return ""
		end
	  end
    end
  end
end
