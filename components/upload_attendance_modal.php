<!-- Upload CSV Modal -->
<div class="modal fade" id="uploadModal" tabindex="-1">
    <div class="modal-dialog">
        <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title">Import Attendance CSV</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
            </div>
            <div class="modal-body">
                <form id="uploadForm" enctype="multipart/form-data">
                    <!-- Subject Selection -->
                    <div class="mb-3">
                        <label class="form-label">Select Subject:</label>
                        <select name="subject_id" id="subjectSelect" class="form-select" required>
                            <option value="">-- Choose Subject --</option>
                            <?php
                            // Get instructor's subjects
                            $user_id = $_SESSION['user_id'];
                            $subjects_query = $conn->prepare("
                                SELECT s.id, s.subject_code, s.subject_name 
                                FROM subjects_tbl s
                                INNER JOIN subject_instructors_tbl si ON s.id = si.subject_id
                                WHERE si.instructor_id = ?
                                ORDER BY s.subject_name
                            ");
                            $subjects_query->bind_param("i", $user_id);
                            $subjects_query->execute();
                            $subjects_result = $subjects_query->get_result();
                            
                            while ($subject = $subjects_result->fetch_assoc()) {
                                echo '<option value="' . $subject['id'] . '" 
                                      data-code="' . htmlspecialchars($subject['subject_code']) . '"
                                      data-name="' . htmlspecialchars($subject['subject_name']) . '">' 
                                      . htmlspecialchars($subject['subject_name']) 
                                      . ' (' . htmlspecialchars($subject['subject_code']) . ')</option>';
                            }
                            ?>
                        </select>
                        <small class="text-muted">Only students enrolled in this subject will be recorded</small>
                    </div>

                    <div class="mb-3">
                        <label class="form-label">Select Date:</label>
                        <input type="date" name="attendance_date" class="form-control" required>
                    </div>

                    <div class="mb-3">
                        <label class="form-label">Select Time In:</label>
                        <input type="time" name="time_in" class="form-control" required>
                    </div>

                    <div class="mb-3">
                        <label class="form-label">CSV File:</label>
                        <input type="file" name="csv_file" class="form-control" accept=".csv" required>
                        <small class="text-muted">Format: student_no (one per line)</small>
                    </div>

                    <div class="alert alert-info">
                        <strong>CSV Format Example:</strong><br>
                        <code>student_no<br>019-464<br>024-454<br>025-458</code>
                    </div>
                </form>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
                <button type="button" id="uploadBtn" class="btn btn-success">
                    <i class="bi bi-upload"></i> Upload
                </button>
            </div>
        </div>
    </div>
</div>