<?php
header('Content-Type: application/json');
include __DIR__.'/../includes/db_connect.php';

// Get JSON input
$input = json_decode(file_get_contents('php://input'), true);

if (!isset($input['descriptor'])) {
    echo json_encode(['success' => false, 'message' => 'No descriptor provided']);
    exit;
}

$currentDescriptor = $input['descriptor'];

try {
    // Get all users with face recognition enabled
    $query = "SELECT id, name, email, face_descriptor 
              FROM users 
              WHERE face_descriptor IS NOT NULL 
              AND face_descriptor != ''";
    
    $result = mysqli_query($conn, $query);
    
    if (!$result) {
        throw new Exception('Database query failed: ' . mysqli_error($conn));
    }
    
    // STRICTER THRESHOLD - 0.45 for security
    $MATCH_THRESHOLD = 0.45; 
    
    // Track closest match for debugging
    $closestDistance = PHP_FLOAT_MAX;
    $closestUser = null;
    
    while ($user = mysqli_fetch_assoc($result)) {
        $savedDescriptor = json_decode($user['face_descriptor'], true);
        
        if (!$savedDescriptor || !is_array($savedDescriptor)) {
            continue;
        }
        
        // NEW: Check if multi-descriptor format (array of arrays)
        $isMultiDescriptor = isset($savedDescriptor[0]) && is_array($savedDescriptor[0]);
        
        $minDistance = PHP_FLOAT_MAX;
        
        if ($isMultiDescriptor) {
            // Compare against ALL 5 stored descriptors, get minimum distance
            foreach ($savedDescriptor as $storedDesc) {
                if (!is_array($storedDesc) || count($storedDesc) !== 128) {
                    continue;
                }
                
                $distance = calculateEuclideanDistance($currentDescriptor, $storedDesc);
                
                if ($distance < $minDistance) {
                    $minDistance = $distance;
                }
            }
        } else {
            // Old format: single descriptor (backward compatibility)
            if (count($savedDescriptor) !== 128 || count($currentDescriptor) !== 128) {
                continue;
            }
            
            $minDistance = calculateEuclideanDistance($currentDescriptor, $savedDescriptor);
        }
        
        // Track closest match across all users
        if ($minDistance < $closestDistance) {
            $closestDistance = $minDistance;
            $closestUser = $user;
        }
        
        // Check if faces match with STRICT threshold
        if ($minDistance < $MATCH_THRESHOLD) {
            // Calculate similarity percentage
            $similarity = max(0, (1 - ($minDistance / 2)) * 100);
            
            // Log the match
            error_log("Face duplicate detected - User: {$user['name']}, Distance: $minDistance, Threshold: $MATCH_THRESHOLD");
            
            echo json_encode([
                'success' => true,
                'isDuplicate' => true,
                'userId' => $user['id'],
                'userName' => $user['name'],
                'userEmail' => $user['email'],
                'distance' => round($minDistance, 4),
                'similarity' => round($similarity, 1),
                'threshold' => $MATCH_THRESHOLD,
                'matchType' => $isMultiDescriptor ? 'multi-descriptor (5 images)' : 'single-descriptor (1 image)'
            ]);
            exit;
        }
    }
    
    // No duplicate found
    if ($closestUser) {
        error_log("No duplicate found - Closest match: {$closestUser['name']}, Distance: $closestDistance (threshold: $MATCH_THRESHOLD)");
    }
    
    echo json_encode([
        'success' => true,
        'isDuplicate' => false,
        'message' => 'Face is unique',
        'closestDistance' => round($closestDistance, 4),
        'threshold' => $MATCH_THRESHOLD,
        'debug' => [
            'totalUsersChecked' => mysqli_num_rows($result),
            'closestMatch' => $closestUser ? $closestUser['name'] : 'None'
        ]
    ]);
    
} catch (Exception $e) {
    error_log("Face check error: " . $e->getMessage());
    echo json_encode([
        'success' => false,
        'message' => 'Database error: ' . $e->getMessage()
    ]);
}

/**
 * Calculate Euclidean distance between two face descriptors
 * Lower distance = more similar faces
 * 
 * Ranges:
 * - 0.0 - 0.3: Same person (very high confidence)
 * - 0.3 - 0.5: Same person (high confidence)
 * - 0.5 - 0.7: Possibly same person (medium confidence)
 * - 0.7+: Different person
 */
function calculateEuclideanDistance($descriptor1, $descriptor2) {
    if (count($descriptor1) !== count($descriptor2)) {
        throw new Exception('Descriptor lengths do not match');
    }
    
    $sum = 0;
    for ($i = 0; $i < count($descriptor1); $i++) {
        $diff = floatval($descriptor1[$i]) - floatval($descriptor2[$i]);
        $sum += $diff * $diff;
    }
    
    return sqrt($sum);
}
?>