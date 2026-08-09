/**
 * View Absences Modal Handler
 * Displays students with specified number of absences
 */

function viewAbsences(section, minAbsences) {
    // Update modal title and info
    const modalTitle = minAbsences === 3 ? 'Students with 3+ Absences' : 'Students with 5+ Absences';
    document.getElementById('absencesModalTitle').textContent = modalTitle;
    document.getElementById('absencesInfoTitle').textContent = modalTitle;
    document.getElementById('sectionName').textContent = section;
    document.getElementById('absenceCount').textContent = minAbsences;
    
    // Set export form values
    document.getElementById('exportSection').value = section;
    document.getElementById('exportMinAbsences').value = minAbsences;
    
    // Show modal
    const modal = new bootstrap.Modal(document.getElementById('viewAbsencesModal'));
    modal.show();
    
    // Show loading state
    document.getElementById('absencesLoadingState').style.display = 'block';
    document.getElementById('absencesContent').style.display = 'none';
    document.getElementById('absencesErrorState').style.display = 'none';
    
    // Fetch data via AJAX
    fetch('../api/get_absences_data.php', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: `section=${encodeURIComponent(section)}&min_absences=${minAbsences}`
    })
    .then(response => response.json())
    .then(data => {
        // Hide loading
        document.getElementById('absencesLoadingState').style.display = 'none';
        
        if (data.success) {
            // Show content
            document.getElementById('absencesContent').style.display = 'block';
            
            if (data.students.length === 0) {
                // Show empty state
                document.getElementById('absencesEmptyState').style.display = 'block';
                document.querySelector('.table-responsive').style.display = 'none';
                document.getElementById('exportAbsencesBtn').disabled = true;
            } else {
                // Populate table
                const tbody = document.getElementById('absencesTableBody');
                tbody.innerHTML = '';
                
                data.students.forEach((student, index) => {
                    const row = document.createElement('tr');
                    
                    // Calculate absence percentage
                    const absenceRate = ((student.absences / student.total_classes) * 100).toFixed(1);
                    
                    // Determine badge color based on absences
                    let badgeClass = 'bg-warning';
                    if (student.absences >= 5) {
                        badgeClass = 'bg-danger';
                    } else if (student.absences >= 7) {
                        badgeClass = 'bg-dark';
                    }
                    
                    row.innerHTML = `
                        <td>${index + 1}</td>
                        <td><strong>${escapeHtml(student.student_no)}</strong></td>
                        <td>${escapeHtml(student.name)}</td>
                        <td>${escapeHtml(student.course)}</td>
                        <td class="text-center">
                            <span class="badge bg-secondary">${student.total_classes}</span>
                        </td>
                        <td class="text-center">
                            <span class="badge bg-success">${student.attended}</span>
                        </td>
                        <td class="text-center">
                            <span class="badge ${badgeClass}">
                                ${student.absences} (${absenceRate}%)
                            </span>
                        </td>
                    `;
                    
                    tbody.appendChild(row);
                });
                
                document.getElementById('absencesEmptyState').style.display = 'none';
                document.querySelector('.table-responsive').style.display = 'block';
                document.getElementById('exportAbsencesBtn').disabled = false;
            }
        } else {
            // Show error
            document.getElementById('absencesErrorState').style.display = 'block';
            document.getElementById('absencesErrorMessage').textContent = data.message || 'Unable to load data.';
        }
    })
    .catch(error => {
        console.error('Error:', error);
        document.getElementById('absencesLoadingState').style.display = 'none';
        document.getElementById('absencesErrorState').style.display = 'block';
        document.getElementById('absencesErrorMessage').textContent = 'Network error. Please try again.';
    });
}

// Helper function to escape HTML
function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}