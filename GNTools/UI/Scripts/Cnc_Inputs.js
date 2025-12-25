(function ($) {
  $.widget("cnc.cncInputs", {
    options: {
      step: 1,
      value: 0,
      units: "mm",
      dangerZone: null,
      wheel: false,
      precisionStep: true,
      number: false,
	  decimal: 3,
      readonly: false
    },

    _create: function () {
	  const input = this.element;

	  // Parcours toutes les options du widget
	  for (let key in this.options) {
		if (!this.options.hasOwnProperty(key)) continue;

		// Si l'input a un attribut correspondant, on prend sa valeur
		const attrVal = input.attr(key);
		if (attrVal !== undefined) {
		  if (key == "decimal")
			console.log("decimal",attrVal)
		  if (key == "value")
			console.log("value",attrVal)
		  // Convertir en nombre si l'option est numérique
		  if (typeof this.options[key] === "number") {
		    this.options[key] = parseFloat(attrVal);
		  } else if (typeof this.options[key] === "boolean") {
			this.options[key] = attrVal === "true" || attrVal === true;
		  } else {
			this.options[key] = attrVal;
		  }
		  if (key == "decimal")
			console.log("decimal val ",this.options.decimal)
		  if (key == "value")
			console.log("value val",this.options.value)
		}
	  }

	  const attrMin = input.attr("min");
	  if (attrMin !== undefined && attrMin !== "" && !isNaN(attrMin)) {
		this.options.min = Number(attrMin);
	  }
	  const attrMax = input.attr("max");
	  if (attrMax !== undefined && attrMax !== "" && !isNaN(attrMax)) {
	    this.options.max = Number(attrMax);
	  }

	  // Si input a déjà une value, on la priorise
	  if (input.val() !== "") {
		this.options.value = parseFloat(input.val());
	  }
      this._build();
      this._bind();
	  this.value(this.options.value);
      this._updateDanger();
	  // mettre à jour le slider dès la création
      this._updateSliderFromValue();
    },

    _build: function () {
      const input = this.element;
      input.addClass("cnc-spinner-input");

      // Wrapper principal
      this.container = $("<div class='cnc-spinner'></div>");
      input.wrap(this.container);
      this.container = input.parent();

	  // Wrapper grid
	  this.gridContainer = $("<div class='cnc-spinner-grid'></div>");
	  this.container.append(this.gridContainer);

      // Wrapper input
      this.inputContainer = $("<div class='cnc-spinner-input-container'></div>");
      input.wrap(this.inputContainer);
      this.inputContainer = input.parent();

	  // Déplacer input-container dans le grid
	  this.inputContainer.appendTo(this.gridContainer);

	  this.spinButtons = $("<div class='cnc-spinner-buttons'></div>");

	  this.btnUp = $("<div class='cnc-spinner-btn cnc-up'>▲</div>");
	  this.btnDown = $("<div class='cnc-spinner-btn cnc-down'>▼</div>");

	  this.spinButtons.append(this.btnUp, this.btnDown);
	  this.inputContainer.append(this.spinButtons);


      // Label unité
      this.unitLabel = $("<span class='cnc-spinner-unit'></span>")
        .text(this.options.units)
        .appendTo(this.gridContainer);

      // Slider custom
      this.sliderContainer = $("<div class='ui-slider ui-slider-horizontal cnc-slider'></div>")
        .appendTo(this.gridContainer);
		
      this.range = $("<div class='ui-slider-range'></div>").appendTo(this.sliderContainer);
      this.handle = $("<span class='ui-slider-handle'></span>").appendTo(this.sliderContainer);


      this.dragging = false;
    },

    _bind: function () {
      const self = this;

      // Input ↔ Slider
      this.element.on("input", () => {
        if (!self.dragging) self._updateSliderFromInput();
      });

	  // Wheel support (global au spinner)
	  if (this.options.wheel) {
	    this.container.on("wheel.cncSpinner", (e) => {
		  e.preventDefault();
		  e.stopPropagation();

		  let delta = e.originalEvent.deltaY < 0 ? 1 : -1;
		  let step = this.options.step;

		  if (this.options.precisionStep) {
		    if (e.shiftKey && e.ctrlKey) step *= 1000;
		    else if (e.shiftKey) step *= 100;
		    else if (e.ctrlKey) step *= 10;
		  }

		  this.value(this.value() + delta * step);
		  this._updateSliderFromValue();
	    });
	  }
      // Drag events
      this.handle.on("mousedown", (e) => {
        self.dragging = true;
        e.preventDefault();
      });
      $(document).on("mouseup", () => self.dragging = false);
      $(document).on("mousemove", (e) => {
        if (self.dragging) self._updateValueFromMouse(e.clientX);
      });

      // number option
      if (this.options.number) {
        // Pendant la saisie
        this.element.on("input", (e) => {
          let val = this.element.val().replace(/[^0-9.]/g, "");
          const parts = val.split(".");
          if (parts.length > 2) val = parts[0] + "." + parts.slice(1).join("");
          this.element.val(val);
        });
        // Au blur
        this.element.on("blur", () => {
          let v = Number(this.element.val() || 0);
          this.value(v); // ici toFixed
        });
      }

      // readonly
/*      if (this.options.readonly) this.element.attr("readonly", true);*/
	  if (this.options.readonly) {
		this.element.prop("readonly", true);
		this.btnUp.add(this.btnDown).addClass("disabled");
		this.handle.off("mousedown");
        this.container.off("wheel");
	  }
 

	  this.btnUp.on("mousedown", (e) => {
	    e.preventDefault();
	    this._startSpin(+1, e);
	  }); 

	  this.btnDown.on("mousedown", (e) => {
	    e.preventDefault();
	    this._startSpin(-1, e);
	  });
	  
	  $(document).on("mouseup.cncSpinner mouseleave.cncSpinner", () => {
		this._stopSpin();
	  });
	  
	  this.element.on("keydown", (e) => {
	    let handled = true;

	    switch (e.key) {
		  case "ArrowUp":
		    this._stepValue(+1, e);
		    break;

		  case "ArrowDown":
		    this._stepValue(-1, e);
		    break;

		  case "PageUp":
		    this.value(this.value() + this.options.step * 10);
		    break;

		  case "PageDown":
		    this.value(this.value() - this.options.step * 10);
		    break;

		  case "Home":
		    this.value(this.options.min);
		    break;

		  case "End":
		    this.value(this.options.max);
		    break;

		  default:
		    handled = false;
	    }

	    if (handled) e.preventDefault();
	  });
    },
	
	_startSpin: function (dir, e) {
	  // 1 step immédiat (clic)
	  this._stepValue(dir, e);

	  // 2️ reset
	  this._spinAcceleration = 1;

	  // 3️ délai avant répétition
	  this._spinTimeout = setTimeout(() => {
		this._spinInterval = setInterval(() => {
		  this._stepValue(dir * this._spinAcceleration, e);

		  // accélération douce
		  this._spinAcceleration = Math.min(
			this._spinAcceleration + 0.25,
			20
		  );
		}, 80);
	  }, 350); // ← DÉLAI CRITIQUE
	},

	_stopSpin: function () {
	  clearTimeout(this._spinTimeout);
	  clearInterval(this._spinInterval);

	  this._spinTimeout = null;
	  this._spinInterval = null;
	},
	
	_stepValue: function (dir, event) {
	  let step = this.options.step;

	  if (this.options.precisionStep && event) {
		if (event.shiftKey && event.ctrlKey) step *= 1000;
		else if (event.shiftKey) step *= 100;
		else if (event.ctrlKey) step *= 10;
	  }

	  this.value(this.value() + dir * step);
	},

	_isAutoRange: function () {
	  return typeof this.options.min !== "number" || typeof this.options.max !== "number";
	},

    _updateValueFromMouse: function (clientX) {
      const rect = this.sliderContainer[0].getBoundingClientRect();
      let ratio = (clientX - rect.left) / rect.width;
      ratio = Math.min(1, Math.max(0, ratio));
	  const range = this._getEffectiveRange();
	  let rawValue = range.min + ratio * (range.max - range.min);
      let steppedValue = Math.round(rawValue / this.options.step) * this.options.step;
      this.value(steppedValue);
      this._updateSliderFromValue();
    },

	_updateSliderFromValue: function () {
	  const val = this.options.value;
	  const range = this._getEffectiveRange();
	  let clamped;

	  if (this._isAutoRange()) {
		// auto-range : slider centré, handle bouge autour de la valeur
		const span = range.max - range.min;
		// position du handle par rapport au milieu
		clamped = ((val - (range.min + span / 2)) / span + 0.5) * 100;
	  } else {
		// slider normal
		const denom = range.max - range.min;
		if (denom <= 0) return;
		clamped = ((val - range.min) / denom) * 100;
	  }

	  clamped = Math.max(0, Math.min(100, clamped));

	  this.handle.css("left", clamped + "%");
	  this.range.css("width", clamped + "%");

	  // Danger zone
	  if (
		this.options.dangerZone &&
		val >= this.options.dangerZone.min &&
		val <= this.options.dangerZone.max
	  ) {
		this.range.addClass("cnc-danger");
		this.element.addClass("cnc-danger");
	  } else {
		this.range.removeClass("cnc-danger");
		this.element.removeClass("cnc-danger");
	  }
	},

    _updateSliderFromInput: function () {
      this._updateSliderFromValue();
    },

    value: function (v) {
	  if (v !== undefined) {
		console.log("value in ",v)

        v = Number(v);               // convertit string → number
		if (isNaN(v)) v = 0; // fallback si valeur invalide

		console.log("isNaN ",v)
		
        // fallback min/max si pas définis
        const min = (typeof this.options.min === "number") ? this.options.min : -Infinity;
        const max = (typeof this.options.max === "number") ? this.options.max : Infinity;
        v = Math.min(max, Math.max(min, v));
		console.log("min max ",v)
		v = Number(v.toFixed(this.options.decimal))
		console.log("fixed ",v,this.options.decimal)
		this.element.val(v);
        this.options.value = v;
        this._updateSliderFromValue();
      }
      return this.options.value;	
/*		
      if (v === undefined) return Number(this.element.val());

      v = Math.min(this.options.max, Math.max(this.options.min, v));
      this.element.val(v.toFixed(3));
      this._updateSliderFromValue();
      return v;*/
    },

	_getEffectiveRange: function () {
	  const v = this.options.value;
	  const step = this.options.step || 1;
	  const span = step * 100; // réglable plus tard

	  const hasMin = typeof this.options.min === "number";
	  const hasMax = typeof this.options.max === "number";

	  if (hasMin && hasMax && this.options.max > this.options.min) {
		return { min: this.options.min, max: this.options.max };
	  }

	  if (hasMin && !hasMax) {
		return { min: this.options.min, max: v + span };
	  }

	  if (!hasMin && hasMax) {
		return { min: v - span, max: this.options.max };
	  }

	  return { min: v - span, max: v + span };
	},

    setUnits: function (u) {
      this.options.units = u;
      this.unitLabel.text(u);
    },

	_updateDanger: function () {
	  if (!this.options.dangerZone) return;

	  const val = this.value();
	  const dz = this.options.dangerZone;

	  if (val >= dz.min && val <= dz.max) {
		this.range.addClass("cnc-danger");   // colorer la range
		this.element.addClass("cnc-danger"); // input aussi si tu veux
	  } else {
		this.range.removeClass("cnc-danger");
		this.element.removeClass("cnc-danger");
	  }
	},

    setDangerZone: function (dz) {
      this.options.dangerZone = dz;
      this._updateSliderFromValue();
    },

    _destroy: function () {
      this.sliderContainer.remove();
      this.unitLabel.remove();
      this.element.removeClass("cnc-spinner-input").unwrap().unwrap();
    }
  });
})(jQuery);