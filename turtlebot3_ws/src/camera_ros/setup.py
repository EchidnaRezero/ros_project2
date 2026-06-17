from setuptools import setup

package_name = 'camera_ros'

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
    description='Jetson CSI camera and DetectNet publisher for the AMR delivery mission',
    license='LicenseRef-Portfolio-Demo',
    tests_require=['pytest'],
    entry_points={
        'console_scripts': [
            'publisher = camera_ros.publisher:main',
            'video_test = camera_ros.video_test:main',
        ],
    },
)
