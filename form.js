document.addEventListener('DOMContentLoaded', function () {
  // ----- Configurable defaults -----
  const gpuDefault = 'rtx4090';

  // Defaults per Instance size. Adjust to your policy.
  const instanceSizeDefaults = {
    Small:  { cores: 4,  memcore: 4,  numGpus: 1 },
    Medium: { cores: 8, memcore: 4,  numGpus: 1 },
    Large:  { cores: 16, memcore: 4,  numGpus: 1 },
    Custom: { cores: 4,  memcore: 4,  numGpus: 1 }
  };
  const instanceDefault = 'Medium';

  // ----- Default QoS per account -----
  const defaultQosByAccount = {
    gratis: 'job_gratis',
    paygo: 'job_interactive',
    invest: '',        // adjust to a valid default for your 'invest' policy
    teaching: 'job_teaching'
  };

  // ----- Rules from your matrix (v6), now including hide_gpu and using checkbox for optional GPU QoS -----
  // hide_gpu means: by default hide GPU controls for that QoS under that account.
  // For QoS that are "optional GPU" (job_gratis, job_interactive), we will override hide_gpu based on the checkbox.
  const accountRules = [
    // gratis
    { account: 'gratis', qos: /^job_gratis$/,            hide_gpu: true  }, // optional GPU via checkbox
    { account: 'gratis', qos: /^job_cpu_preemptable$/,   hide_gpu: true  },
    { account: 'gratis', qos: /^job_gpu_preemptable$/,   hide_gpu: false },

    // paygo
    { account: 'paygo',  qos: /^job_interactive$/,       hide_gpu: true  }, // optional GPU via checkbox
    { account: 'paygo',  qos: /^job_cpu$/,               hide_gpu: true  },
    { account: 'paygo',  qos: /^job_gpu$/,               hide_gpu: false },

    // invest
    { account: 'invest', qos: /^job_icpu-.*$/,           hide_gpu: true  },
    { account: 'invest', qos: /^job_gpu_(?!preemptable).*$/, hide_gpu: false },

    // teaching
    { account: 'teaching', qos: /^job_teaching$/,        hide_gpu: true  } // optional GPU via checkbox
  ];

  // QoS where GPU can be optionally requested with a checkbox
  const optionalGpuQos = new Set(['job_gratis', 'job_interactive', 'job_teaching']);

  // ----- Grab form elements -----
  const form             = document.getElementById('new_batch_connect_session_context');
  const moduleSelect     = document.getElementById('batch_connect_session_context_auto_modules_rstudio_server');
  const accountSelect    = document.getElementById('batch_connect_session_context_auto_accounts');
  const qosSelect        = document.getElementById('batch_connect_session_context_auto_qos');
  const gpuCheckbox      = document.getElementById('batch_connect_session_context_global_gpu_checkbox');
  const gpuSelect        = document.getElementById('batch_connect_session_context_global_type_gpu');
  const instanceSelect   = document.getElementById('batch_connect_session_context_global_instance');
  const coresInput       = document.getElementById('batch_connect_session_context_global_cores');
  const memcoreInput     = document.getElementById('batch_connect_session_context_global_memcore');
  const numGpusInput     = document.getElementById('batch_connect_session_context_global_num_gpus');
  const wckeyInput       = document.getElementById('batch_connect_session_context_global_wckey');
  const hoursInput       = document.getElementById('batch_connect_session_context_global_bc_num_hours');
  const advancedModeSel  = document.getElementById('batch_connect_session_context_global_advanced_mode');
  const envTextarea      = document.getElementById('batch_connect_session_context_global_custom_environment');
  const reservationInput = document.getElementById('batch_connect_session_context_global_reservation');

  // ----- Helpers -----
  function rulesForAccount(account) {
    return accountRules.filter(r => r.account === account);
  }

  function isQosVisibleForAccount(account, qosValue) {
    return rulesForAccount(account).some(rule => rule.qos.test(qosValue));
  }

  function findFirstVisibleQosOption(account) {
    return Array.from(qosSelect.options).find(opt => isQosVisibleForAccount(account, opt.value));
  }

  function setBlockVisibility(fieldEl, hide) {
    if (!fieldEl) return;
    const block = fieldEl.closest('.mb-3');
    if (block) block.style.display = hide ? 'none' : '';
  }

  function ensureInstanceDefault() {
    if (instanceSelect && !instanceSelect.value) {
      const hasDefault = Array.from(instanceSelect.options).some(o => o.value === instanceDefault);
      if (hasDefault) instanceSelect.value = instanceDefault;
    }
  }

  function applyInstanceDefaults(instanceValue, gpuAllowed) {
    const defs = instanceSizeDefaults[instanceValue] || instanceSizeDefaults[instanceDefault];
    if (coresInput)   coresInput.value   = String(defs.cores);
    if (memcoreInput) memcoreInput.value = String(defs.memcore);
    const numGpusVal = gpuAllowed ? defs.numGpus : 0;
    if (numGpusInput) numGpusInput.value = String(numGpusVal);
  }

  function ensureGpuDefault() {
    if (gpuSelect && gpuSelect.closest('.mb-3').style.display !== 'none' && !gpuSelect.value) {
      const hasDefault = Array.from(gpuSelect.options).some(o => o.value === gpuDefault);
      if (hasDefault) gpuSelect.value = gpuDefault;
    }
  }

  // More explicit version of computeGpuVisibility to remove ambiguity:
  function computeGpuVisibilityExplicit(account, qos) {
    const rules = rulesForAccount(account);
    const matchingRule = rules.find(rule => rule.qos.test(qos));
    const baseHide = matchingRule ? !!matchingRule.hide_gpu : true;

    if (optionalGpuQos.has(qos)) {
      const showCheckbox = true;
      const checked = gpuCheckbox ? gpuCheckbox.checked : false;
      // Logic:
      // - If the base rule hides GPU, user can turn it on by checking the box.
      // - If the base rule shows GPU, GPU is visible even if box is unchecked, but you may want to enforce checkbox for consistency.
      // To strictly require checkbox for optional QoS, set gpuHidden = !checked.
      const requireCheckboxForOptional = true; // set false to allow GPU without checkbox when baseHide=false
      const gpuHidden = requireCheckboxForOptional ? !checked : baseHide && !checked;
      return { showCheckbox, gpuHidden };
    } else {
      return { showCheckbox: false, gpuHidden: baseHide };
    }
  }

  // ----- Main update -----
  function updateFormOptions({ forceDefaultQos = false } = {}) {
    const account = accountSelect.value;

    // QoS list visibility per account
    Array.from(qosSelect.options).forEach(option => {
      const visible = isQosVisibleForAccount(account, option.value);
      option.style.display = visible ? '' : 'none';
    });

    // Default QoS if needed
    const currentQos = qosSelect.value;
    const currentVisible = currentQos && isQosVisibleForAccount(account, currentQos);
    let desiredQos = currentQos;
    if (forceDefaultQos || !currentVisible) {
      const defaultQos = defaultQosByAccount[account];
      if (defaultQos && isQosVisibleForAccount(account, defaultQos)) {
        desiredQos = defaultQos;
      } else {
        const firstVisible = findFirstVisibleQosOption(account);
        if (firstVisible) desiredQos = firstVisible.value;
      }
      if (desiredQos && desiredQos !== qosSelect.value) {
        qosSelect.value = desiredQos;
      }
    }

    const qos = qosSelect.value;

    // Combine accountRules hide_gpu with checkbox for optional QoS
    const { showCheckbox, gpuHidden } = computeGpuVisibilityExplicit(account, qos);

    // Show/hide the checkbox block depending on QoS
    if (gpuCheckbox) {
      const gpuCheckboxBlock = gpuCheckbox.closest('.mb-3');
      if (gpuCheckboxBlock) gpuCheckboxBlock.style.display = showCheckbox ? '' : 'none';
    }

    // GPU controls visibility
    setBlockVisibility(gpuSelect, gpuHidden);

    const gpuAllowed = !gpuHidden;

    // Instance selector ALWAYS visible
    ensureInstanceDefault();

    // Custom Instance auxiliary fields only for Custom
    const isCustomInstance = instanceSelect.value === 'Custom';
    setBlockVisibility(coresInput,   !isCustomInstance);
    setBlockVisibility(memcoreInput, !isCustomInstance);
    setBlockVisibility(numGpusInput, !isCustomInstance);

    // Apply per-instance defaults; if GPU not allowed, num_gpus becomes 0
    applyInstanceDefaults(instanceSelect.value, gpuAllowed);

    // Ensure GPU type default when visible
    ensureGpuDefault();

    const isTeaching = account === 'teaching';
    setBlockVisibility(reservationInput, !isTeaching);
    if (account !== 'teaching' && reservationInput) {
      reservationInput.value = '';
    }
  }

  // ----- Event listeners -----
  accountSelect.addEventListener('change', () => updateFormOptions({ forceDefaultQos: true }));
  qosSelect.addEventListener('change',     () => updateFormOptions({ forceDefaultQos: false }));
  instanceSelect.addEventListener('change',() => updateFormOptions({ forceDefaultQos: false }));
  if (gpuCheckbox) {
    gpuCheckbox.addEventListener('change', () => updateFormOptions({ forceDefaultQos: false }));
  }

  // ----- Initialize -----
  updateFormOptions({ forceDefaultQos: true });

});
