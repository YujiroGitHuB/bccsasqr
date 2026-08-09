function viewAttendance(subject, section, status, date) {
    // Show modal with animation
    const modal = new bootstrap.Modal(document.getElementById('attendanceModal'));
    modal.show();

    // Update modal title with gradient icon
    const statusIcon = status === 'present' ? 'check-circle-fill' : 'x-circle-fill';
    const statusColor = status === 'present' ? 'success' : 'danger';
    const statusText = status.charAt(0).toUpperCase() + status.slice(1);

    document.getElementById('attendanceModalLabel').innerHTML =
        `<i class="bi bi-${statusIcon} text-${statusColor}"></i> ${statusText} Students - ${subject} - Section ${section}`;

    // Format the selected date properly
    let formattedDate;
    try {
        const selectedDate = new Date(date + 'T00:00:00'); // Add time to avoid timezone issues
        formattedDate = selectedDate.toLocaleDateString('en-US', {
            weekday: 'long',
            year: 'numeric',
            month: 'long',  
            day: 'numeric'
        });
    } catch (error) {
        formattedDate = date; // Fallback to raw date if parsing fails
    }
    document.getElementById('attendanceModalDate').textContent = formattedDate;

    // Show loading spinner
    document.getElementById('attendanceModalBody').innerHTML = `
        <div class="text-center py-5">
            <div class="spinner-border text-primary" style="width: 3rem; height: 3rem;" role="status">
                <span class="visually-hidden">Loading...</span>
            </div>
            <p class="text-white-50 mt-3 fw-semibold">Loading attendance data...</p>
        </div>
    `;

    // Fetch data via AJAX with cache busting and date parameter
    const timestamp = new Date().getTime();
    fetch(`../components/view_attendance.php?subject=${encodeURIComponent(subject)}&section=${encodeURIComponent(section)}&status=${status}&date=${encodeURIComponent(date)}&_t=${timestamp}`, {
        method: 'GET',
        cache: 'no-store', // Force fresh data
        headers: {
            'Cache-Control': 'no-cache',
            'Pragma': 'no-cache'
        }
    })
        .then(response => {
            if (!response.ok) {
                throw new Error('Network response was not ok');
            }
            return response.text();
        })
        .then(data => {
            document.getElementById('attendanceModalBody').innerHTML = data;
        })
        .catch(error => {
            document.getElementById('attendanceModalBody').innerHTML = `
                <div class="alert alert-danger rounded-4 border-0">
                    <i class="bi bi-exclamation-triangle-fill"></i> Error loading data: ${error.message}
                </div>
            `;
        });
}
