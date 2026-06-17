from setuptools import find_packages, setup

package_name = 'item_detector'

setup(
    name=package_name,
    version='0.0.0',
    packages=find_packages(exclude=['test']),
    data_files=[
        ('share/ament_index/resource_index/packages',
            ['resource/' + package_name]),
        ('share/' + package_name, ['package.xml']),
    ],
    install_requires=['setuptools'],
    zip_safe=True,
    maintainer='Rtree Mission Team',
    maintainer_email='rtree-mission@example.invalid',
    description='Object detection result mapper for recall-mode manipulator motions',
    license='LicenseRef-Portfolio-Demo',
    extras_require={
        'test': [
            'pytest',
        ],
    },
    entry_points={
        'console_scripts': [
            'detection = item_detector.detection:main',
        ],
    },
)
