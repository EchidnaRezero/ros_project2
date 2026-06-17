from setuptools import find_packages, setup

package_name = 'rtreebot'

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
    description='WebSocket delivery mission bridge and controller for AMR manipulation mission',
    license='LicenseRef-Portfolio-Demo',
    tests_require=['pytest'],
    entry_points={
        'console_scripts': [
            'delivery_bridge = rtreebot.delivery_bridge_node:main',
            'delivery_ctrl = rtreebot.delivery_ctrl:main',
        ],
    },
)
