#!/home/jetson/mp_env/bin/python3

import sys
sys.path.append('/home/jetson/mp_env/lib/python3.8/site-packages')
import rclpy
from rclpy.node import Node
from std_msgs.msg import String, Int32
from sensor_msgs.msg import CompressedImage
import cv2
import mediapipe as mp
import numpy as np


class HandTrackerNode(Node):
    def __init__(self):
        super().__init__('hand_tracker_node')
        self.declare_parameter('lambda_sign_required_count', 5)
        self.declare_parameter('thumbs_up_required_count', 5)
        self.declare_parameter('show_debug_window', True)

        self.get_logger().info("MediaPipe Gesture Node Started")

        self.manipulator_pub = self.create_publisher(
            Int32, '/manipulator/motion_id', 10
        )

        self.video_sub = self.create_subscription(
            CompressedImage,
            '/camera',
            self.image_callback,
            10
        )

        self.mediapipe_start_sub = self.create_subscription(
            String,
            '/mediapipe/start',
            self.start_callback,
            10
        )

        self.mp_hands = mp.solutions.hands
        self.mp_drawing = mp.solutions.drawing_utils
        self.hands = self.mp_hands.Hands(
            max_num_hands=1,
            min_detection_confidence=0.6,
            min_tracking_confidence=0.5
        )
        self.mediapipe_start = False
        self.motion_map = {
            'driver': 3,
            'pen': 4,
            'block': 1,
            'wrench': 2,
        }
        self.items = list(self.motion_map.keys())
        self.item = None
        self.gesture_mode = "lambda_sign"
        self.gesture_count = 0

    def start_callback(self, msg):
        data = msg.data.strip()
        if ':' in data:
            item, gesture_mode = data.split(':', 1)
        else:
            item = data
            gesture_mode = "lambda_sign"

        if item not in self.items:
            return
        if gesture_mode not in ["lambda_sign", "thumbs_up"]:
            return

        self.get_logger().info(
            f"Start mediaPipe gesture detection: item={item}, gesture={gesture_mode}"
        )
        self.mediapipe_start = True
        self.item = item
        self.gesture_mode = gesture_mode
        self.gesture_count = 0

    def detect_lambda_sign(self, landmarks):
        thumb_tip = landmarks.landmark[self.mp_hands.HandLandmark.THUMB_TIP]
        thumb_ip = landmarks.landmark[self.mp_hands.HandLandmark.THUMB_IP]
        index_tip = landmarks.landmark[
            self.mp_hands.HandLandmark.INDEX_FINGER_TIP
        ]

        if thumb_tip.y < thumb_ip.y and index_tip.y > thumb_ip.y:
            return "lambda_sign"
        return "unknown"

    def detect_thumbs_up(self, landmarks):
        thumb_tip = landmarks.landmark[self.mp_hands.HandLandmark.THUMB_TIP]
        thumb_ip = landmarks.landmark[self.mp_hands.HandLandmark.THUMB_IP]
        index_tip = landmarks.landmark[
            self.mp_hands.HandLandmark.INDEX_FINGER_TIP
        ]

        if thumb_tip.y < thumb_ip.y and index_tip.y > thumb_ip.y:
            return "thumbs_up"
        return "unknown"

    def detect_gesture(self, landmarks):
        if self.gesture_mode == "thumbs_up":
            return self.detect_thumbs_up(landmarks)
        return self.detect_lambda_sign(landmarks)

    def image_callback(self, msg: CompressedImage):
        if not self.mediapipe_start:
            return
        # CompressedImage -> OpenCV BGR
        np_arr = np.frombuffer(msg.data, np.uint8)
        frame = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)
        if frame is None:
            self.get_logger().warn("Failed to decode compressed image")
            return

        rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        results = self.hands.process(rgb_frame)

        gesture_msg = String()
        gesture_msg.data = "unknown"

        if results.multi_hand_landmarks:
            for hand_landmarks in results.multi_hand_landmarks:
                self.mp_drawing.draw_landmarks(frame, hand_landmarks, self.mp_hands.HAND_CONNECTIONS)
                gesture_msg.data = self.detect_gesture(hand_landmarks)

        if gesture_msg.data == self.gesture_mode:
            self.gesture_count += 1
        else:
            self.gesture_count = 0

        required_count_param = (
            'thumbs_up_required_count'
            if self.gesture_mode == "thumbs_up"
            else 'lambda_sign_required_count'
        )
        required_count = self.get_parameter(
            required_count_param
        ).get_parameter_value().integer_value

        if self.gesture_count >= required_count:
            motion_id = int(self.motion_map.get(self.item, 0))
            self.manipulator_pub.publish(Int32(data=motion_id))
            self.get_logger().info("Stopping mediaPipe...")
            self.mediapipe_start = False
            self.item = None
            self.gesture_count = 0
            if self.get_parameter(
                'show_debug_window'
            ).get_parameter_value().bool_value:
                cv2.destroyAllWindows()

        if self.get_parameter(
            'show_debug_window'
        ).get_parameter_value().bool_value:
            cv2.imshow("MediaPipe Gesture from CompressedImage", frame)
            if cv2.waitKey(1) & 0xFF == 27:
                self.get_logger().info("Stopping mediaPipe...")
                cv2.destroyAllWindows()
                self.mediapipe_start = False

    def destroy_node(self):
        self.hands.close()
        if self.get_parameter(
            'show_debug_window'
        ).get_parameter_value().bool_value:
            cv2.destroyAllWindows()
        super().destroy_node()


def main(args=None):
    rclpy.init(args=args)
    node = HandTrackerNode()
    rclpy.spin(node)
    node.destroy_node()
    rclpy.shutdown()


if __name__ == '__main__':
    main()
