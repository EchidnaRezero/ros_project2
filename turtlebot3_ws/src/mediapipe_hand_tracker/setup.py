from setuptools import setup

package_name = 'mediapipe_hand_tracker'

setup(
    name=package_name,
    version='0.0.0',
    packages=[package_name],
    data_files=[
        ('share/ament_index/resource_index/packages',
            ['resource/' + package_name]),
        ('share/' + package_name, ['package.xml']),
    ],
    install_requires=['setuptools'],
    zip_safe=True,
    maintainer='Rtree Mission Team',
    maintainer_email='rtree-mission@example.invalid',
    description='MediaPipe hand gesture node for delivery-mode manipulator motions',
    license='LicenseRef-Portfolio-Demo',
    tests_require=['pytest'],
    entry_points={
        'console_scripts': [
            'hand_tracker_node = mediapipe_hand_tracker.hand_tracker_node:main',
        ],
    },
)
