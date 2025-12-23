/* =========================================================
 * Cnc_Inputs.js
 * jQuery UI widgets for CNC inputs
 * ========================================================= */

(function ($) {

  $.widget("cnc.cncSpinner", {

    /* =========================
     * Options
     * ========================= */
    options: {
      min: 0,
      max: 100,
      step: 1,
      value: 0,

      units: "mm",              // "mm" | "inch"
      dangerZone: null,         // { min, max }
      snap: false,              // snap to step
      wheel: true,              // mouse wheel
      precisionStep: true       // shift / ctrl modifiers
    },

    /* =========================
     * Creation
     * ========================= */
    _create: function () {
      this._build();
      this._bind();
      this._applyUnits();
      this.value(this.options.value);
      this._updateDanger();
    },

    /* =========================
     * DOM
     * ========================= */
	_build: function () {
	  const self = this;

	  // Classe input
	  this.element.addClass("cnc-spinner-input");

	  // wrapper principal pour layout Grid
	  this.container = $("<div class='cnc-spinner'></div>");
	  this.element.wrap(this.container);
	  this.container = this.element.parent();

	  // slider sous l’input
	  this.slider = $("<div class='cnc-spinner-slider'></div>").appendTo(this.container);

	  // label unité
	  this.unitLabel = $("<span class='cnc-spinner-unit'></span>").appendTo(this.container);

	  // initialisation spinner jQuery UI
	  this.element.spinner({
		min: this.options.min,
		max: this.options.max,
		step: this.options.step
	  });

	  // slider jQuery UI
	  this.slider.slider({
		min: this.options.min,
		max: this.options.max,
		step: this.options.step,
		value: this.options.value  // ← initialisation directe ici
	  });

	  // récupérer les boutons du spinner et les wrap pour Grid
	  this.spinnerRoot = this.element.closest(".ui-spinner");
	  this.spinnerButtons = this.spinnerRoot.find(".ui-spinner-button");
	  this.spinnerButtons.wrapAll("<div class='cnc-spinner-buttons'></div>");
	},

    /* =========================
     * Events
     * ========================= */
    _bind: function () {
      const self = this;

      /* Spinner → Slider */
      this.element.on("spin change", function () {
        self.slider.slider("value", self.value());
        self._updateDanger();
      });

      /* Slider → Spinner */
      this.slider.on("slide", function (e, ui) {
        self.value(ui.value);
      });

      /* Mouse wheel */
      if (this.options.wheel) {
        this.element.on("wheel", function (e) {
          e.preventDefault();
          const delta = e.originalEvent.deltaY < 0 ? 1 : -1;
          const step = self._getEffectiveStep(e);
          self.value(self.value() + delta * step);
        });
      }
    },

    /* =========================
     * Value handling
     * ========================= */
    value: function (v) {
      if (v === undefined) {
        return this.element.spinner("value");
      }

      v = this._clamp(v);

      if (this.options.snap) {
        v = this._snap(v);
      }

      this.element.spinner("value", v);
      this.slider.slider("value", v);
      this._updateDanger();
    },

    /* =========================
     * Helpers
     * ========================= */
    _clamp: function (v) {
      return Math.min(this.options.max, Math.max(this.options.min, v));
    },

    _snap: function (v) {
      const step = this.options.step;
      return Math.round(v / step) * step;
    },

    _getEffectiveStep: function (e) {
      if (!this.options.precisionStep) {
        return this.options.step;
      }

      if (e.shiftKey) return this.options.step * 10;
      if (e.ctrlKey)  return this.options.step * 0.1;

      return this.options.step;
    },

    _applyUnits: function () {
      this.unitLabel.text(this.options.units);
    },

    _updateDanger: function () {
      if (!this.options.dangerZone) return;

      const v = this.value();
      const dz = this.options.dangerZone;

      this.slider.toggleClass(
        "cnc-danger",
        v >= dz.min && v <= dz.max
      );
    },

    /* =========================
     * Public API
     * ========================= */
    setUnits: function (u) {
      this.options.units = u;
      this._applyUnits();
    },

    /* =========================
     * Destroy
     * ========================= */
    _destroy: function () {
      this.slider.remove();
      this.unitLabel.remove();
      this.element
        .spinner("destroy")
        .removeClass("cnc-spinner-input")
        .unwrap();
    }

  });

})(jQuery);
