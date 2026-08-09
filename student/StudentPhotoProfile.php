<!DOCTYPE html>
<html lang="en">

<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Photo Upload</title>
  <link rel="shortcut icon" href="../assets/images/bcc logo.png" type="image/x-icon">
  <link rel="stylesheet" href="assets/css/style.css">
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/cropperjs/1.6.1/cropper.min.css">
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/bootstrap-icons.min.css">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=DM+Sans:wght@300;400;500;600;700&family=DM+Serif+Display:ital@0;1&display=swap">
  <script src="https://cdnjs.cloudflare.com/ajax/libs/cropperjs/1.6.1/cropper.min.js"></script>
  <script src="https://cdn.jsdelivr.net/npm/sweetalert2@11"></script>
</head>

<body>


  <!-- ── DYNAMIC ISLAND ───────────────────────────────────── -->
  <div class="d-island" id="dIsland">
    <div class="di-photo" id="diPhoto">
      <img id="diPhotoImg" src="" alt="" style="display:none;">
      <div class="di-photo-placeholder" id="diInitials"></div>
    </div>
    <div class="di-text">
      <div class="di-title" id="diTitle">Photo uploaded!</div>
      <div class="di-sub"><span>✓</span><span id="diSub">Saved successfully</span></div>
    </div>
    <div class="di-check" id="diCheck">✓</div>
    <div class="di-bar" id="diBar"></div>
  </div>

  <!-- ── PAGE HEADER ─────────────────────────────────────── -->
  <header class="page-header">
    <img src="../assets/images/bcc logo.png" alt="BCC Logo" class="header-logo">
    <h1>Upload Your <span>Photo</span></h1>
    <p class="page-subtitle">Your face will appear on the scanner screen every time you scan your QR code for attendance.</p>
  </header>

  <!-- ── STEP TRACKER ────────────────────────────────────── -->
  <div class="step-track" id="stepTrack">
    <div class="step-item active" id="dot-1">
      <div class="step-num">1</div>
      <div class="step-lbl">Verify</div>
    </div>
    <div class="step-item" id="dot-2">
      <div class="step-num">2</div>
      <div class="step-lbl">Upload</div>
    </div>
    <div class="step-item" id="dot-3">
      <div class="step-num">3</div>
      <div class="step-lbl">Done</div>
    </div>
  </div>

  <!-- ── CARD ────────────────────────────────────────────── -->
  <div class="card">

    <!-- ════ STEP 1 — VERIFY ════════════════════════════ -->
    <div class="panel active" id="panel-1">
      <div class="step-eyebrow"><i class="bi bi-shield-lock"></i> Step 1 of 3</div>
      <h2>Verify your identity</h2>
      <p class="desc">Enter your <strong>Student Number</strong> and <strong>Last Name</strong> exactly as they appear on your school record.</p>

      <div class="field">
        <div class="field-label"><i class="bi bi-123"></i> Student Number</div>
        <div class="input-shell">
          <i class="bi bi-person-badge lead"></i>
          <input type="text" id="inputStudentNo"
            placeholder="e.g. 024-124"
            autocomplete="off" spellcheck="false" maxlength="20">
        </div>
      </div>

      <div class="field">
        <div class="field-label"><i class="bi bi-person"></i> Last Name</div>
        <div class="input-shell">
          <i class="bi bi-type lead"></i>
          <input type="text" id="inputLastName"
            placeholder="e.g. ABALOS"
            autocomplete="off" spellcheck="false" maxlength="50">
        </div>
        <div class="field-hint"><i class="bi bi-info-circle"></i> Use exact spelling — same as your school record.</div>
      </div>

      <button class="btn btn-primary" id="btnVerify" onclick="verifyStudent()">
        <i class="bi bi-shield-check"></i> Verify Identity
      </button>
    </div>

    <!-- ════ STEP 2 — UPLOAD & CROP ═════════════════════ -->
    <div class="panel" id="panel-2">
      <div class="step-eyebrow"><i class="bi bi-camera"></i> Step 2 of 3</div>
      <h2>Upload your photo</h2>
      <p class="desc">Choose a clear, front-facing photo. You can adjust the crop before saving.</p>

      <div class="verified-card">
        <div class="v-avatar" id="vAvatar">?</div>
        <div>
          <div class="v-name" id="vName">—</div>
          <div class="v-meta" id="vMeta">—</div>
        </div>
        <div class="v-badge"><i class="bi bi-check-circle-fill"></i> Verified</div>
      </div>

      <!-- Source tabs -->
      <div class="src-tabs">
        <button class="src-tab active" id="tabUpload" onclick="switchTab('upload')">
          <i class="bi bi-upload"></i> Upload File
        </button>
        <button class="src-tab" id="tabCamera" onclick="switchTab('camera')">
          <i class="bi bi-camera-video"></i> Use Camera
        </button>
      </div>

      <!-- Upload tab pane -->
      <div id="paneUpload">
        <div class="drop-zone" id="dropZone">
          <input type="file" id="photoFile" accept="image/jpeg,image/png,image/webp" onchange="handleFile(this)">
          <div class="drop-icon"><i class="bi bi-cloud-arrow-up"></i></div>
          <h3>Click to browse or drag & drop</h3>
          <p>JPG, PNG or WEBP &nbsp;·&nbsp; Max 5 MB</p>
        </div>
      </div>

      <!-- Camera tab pane -->
      <div id="paneCamera" style="display:none;">
        <div class="cam-wrap" id="camWrap">
          <div class="cam-placeholder" id="camPlaceholder">
            <i class="bi bi-camera-video-off"></i>
            <span>Camera is off</span>
          </div>
          <video id="camVideo" autoplay playsinline style="display:none;"></video>
          <div class="cam-guide" id="camGuide" style="display:none;"></div>
          <div class="cam-flash" id="camFlash"></div>
        </div>
        <div class="cam-btns">
          <div class="cam-btns-row">
            <button class="btn-cam-action" id="btnCamToggle" onclick="toggleCamera()">
              <i class="bi bi-camera-video" id="camToggleIcon"></i>
              <span id="camToggleLabel">Start Camera</span>
            </button>
            <button class="btn-capture" id="btnCapture" onclick="capturePhoto()" disabled>
              <i class="bi bi-circle-fill" style="font-size:.6rem;"></i> Take Photo
            </button>
          </div>
          <!-- Flashlight — own row, hidden until camera starts -->
          <button class="flashlight-toggle" id="flashlightBtn" style="display:none;" onclick="toggleFlashlight()">
            <i class="bi bi-lightbulb" id="flashlightIcon"></i>
            <span id="flashlightText">Turn On Flash</span>
          </button>
        </div>
      </div>

      <!-- Cropper section (shared) -->
      <div id="cropSection" style="display:none;">
        <div class="crop-wrap"><img id="cropImg" src="" alt=""></div>

        <div class="crop-tip">
          <i class="bi bi-arrows-move"></i>
          <span>Drag to reposition &nbsp;·&nbsp; Pinch or scroll to zoom &nbsp;·&nbsp; Center your face inside the frame.</span>
        </div>

        <div class="preview-row">
          <div id="crop-preview"></div>
          <div class="preview-info">
            <div class="lbl">Live Preview</div>
            <div class="sub">This is how your photo will appear on the attendance scanner.</div>
          </div>
        </div>

        <div class="btn-row">
          <button class="btn btn-ghost" onclick="resetCrop()">
            <i class="bi bi-arrow-counterclockwise"></i> Change Photo
          </button>
          <button class="btn btn-success" id="btnSave" onclick="savePhoto()">
            <i class="bi bi-check-lg"></i> Use This Photo
          </button>
        </div>
      </div>
    </div>

    <!-- ════ STEP 3 — SUCCESS ════════════════════════════ -->
    <div class="panel" id="panel-3">
      <div class="success-wrap">
        <div class="success-photo-ring" id="successRing" style="display:none;">
          <img id="successImg" src="" alt="Your photo">
        </div>
        <div class="success-check" id="successCheck"><i class="bi bi-check-lg"></i></div>
        <h2>Photo uploaded successfully!</h2>
        <p>Your photo is now linked to your student account. It will appear on the attendance screen the next time you scan your QR code.</p>
        <button class="btn btn-done" onclick="resetAll()">
          <i class="bi bi-arrow-repeat"></i> Upload for another student
        </button>
      </div>
    </div>

  </div><!-- end .card -->
  <!-- footer -->
  <?php include __DIR__ . "/../components/footer.php"; ?>

  <script src="assets/js/script.js"></script>
  <!-- detection -->
  <script src="../assets/js/detection.js"></script>
  <!-- flashlight -->
  <script src="../assets/js/flashlight.js"></script>
</body>

</html>