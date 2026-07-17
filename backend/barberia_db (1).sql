CREATE DATABASE  IF NOT EXISTS `barberia_db` /*!40100 DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci */ /*!80016 DEFAULT ENCRYPTION='N' */;
USE `barberia_db`;
-- MySQL dump 10.13  Distrib 8.0.46, for Win64 (x86_64)
--
-- Host: localhost    Database: barberia_db
-- ------------------------------------------------------
-- Server version	8.0.46

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `bloqueos_horario`
--

DROP TABLE IF EXISTS `bloqueos_horario`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `bloqueos_horario` (
  `id` int NOT NULL AUTO_INCREMENT,
  `dia` date NOT NULL,
  `hora_inicio` time NOT NULL,
  `hora_fin` time NOT NULL,
  `motivo` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `bloqueos_horario`
--

LOCK TABLES `bloqueos_horario` WRITE;
/*!40000 ALTER TABLE `bloqueos_horario` DISABLE KEYS */;
/*!40000 ALTER TABLE `bloqueos_horario` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `config_barbero`
--

DROP TABLE IF EXISTS `config_barbero`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `config_barbero` (
  `id` tinyint NOT NULL DEFAULT '1',
  `buffer_minutos` int NOT NULL DEFAULT '5',
  `dias_anticipacion_max` int NOT NULL DEFAULT '30',
  `minutos_anticipacion_min` int NOT NULL DEFAULT '60',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `config_barbero`
--

LOCK TABLES `config_barbero` WRITE;
/*!40000 ALTER TABLE `config_barbero` DISABLE KEYS */;
INSERT INTO `config_barbero` VALUES (1,5,30,60);
/*!40000 ALTER TABLE `config_barbero` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `horario_semanal_default`
--

DROP TABLE IF EXISTS `horario_semanal_default`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `horario_semanal_default` (
  `dia_semana` tinyint NOT NULL,
  `hora_apertura` time NOT NULL,
  `hora_cierre` time NOT NULL,
  `descanso_inicio` time DEFAULT NULL,
  `descanso_fin` time DEFAULT NULL,
  `activo` tinyint(1) NOT NULL DEFAULT '1',
  PRIMARY KEY (`dia_semana`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `horario_semanal_default`
--

LOCK TABLES `horario_semanal_default` WRITE;
/*!40000 ALTER TABLE `horario_semanal_default` DISABLE KEYS */;
INSERT INTO `horario_semanal_default` VALUES (0,'09:00:00','20:00:00','13:00:00','14:00:00',1),(1,'09:00:00','20:00:00','13:00:00','14:00:00',1),(2,'09:00:00','20:00:00','13:00:00','14:00:00',1),(3,'09:00:00','20:00:00','13:00:00','14:00:00',1),(4,'09:00:00','20:00:00','13:00:00','14:00:00',1),(5,'09:00:00','18:00:00',NULL,NULL,1);
/*!40000 ALTER TABLE `horario_semanal_default` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `horarios_disponibles`
--

DROP TABLE IF EXISTS `horarios_disponibles`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `horarios_disponibles` (
  `id` int NOT NULL AUTO_INCREMENT,
  `dia` date NOT NULL,
  `hora` time NOT NULL,
  `disponible` tinyint(1) DEFAULT '1',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `horarios_disponibles`
--

LOCK TABLES `horarios_disponibles` WRITE;
/*!40000 ALTER TABLE `horarios_disponibles` DISABLE KEYS */;
INSERT INTO `horarios_disponibles` VALUES (1,'2026-07-07','09:00:00',0),(2,'2026-07-07','10:00:00',0),(3,'2026-07-07','11:00:00',0);
/*!40000 ALTER TABLE `horarios_disponibles` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `jornada_laboral`
--

DROP TABLE IF EXISTS `jornada_laboral`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `jornada_laboral` (
  `id` int NOT NULL AUTO_INCREMENT,
  `dia` date NOT NULL,
  `hora_apertura` time NOT NULL,
  `hora_cierre` time NOT NULL,
  `descanso_inicio` time DEFAULT NULL,
  `descanso_fin` time DEFAULT NULL,
  `activo` tinyint(1) DEFAULT '1',
  PRIMARY KEY (`id`),
  UNIQUE KEY `dia` (`dia`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `jornada_laboral`
--

LOCK TABLES `jornada_laboral` WRITE;
/*!40000 ALTER TABLE `jornada_laboral` DISABLE KEYS */;
INSERT INTO `jornada_laboral` VALUES (1,'2026-07-13','09:00:00','18:00:00',NULL,NULL,1);
/*!40000 ALTER TABLE `jornada_laboral` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `notificaciones_admin`
--

DROP TABLE IF EXISTS `notificaciones_admin`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `notificaciones_admin` (
  `id` int NOT NULL AUTO_INCREMENT,
  `tipo` varchar(50) NOT NULL DEFAULT 'nueva_reserva',
  `mensaje` varchar(255) NOT NULL,
  `reserva_id` int DEFAULT NULL,
  `leida` tinyint(1) NOT NULL DEFAULT '0',
  `fecha_creacion` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=14 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `notificaciones_admin`
--

LOCK TABLES `notificaciones_admin` WRITE;
/*!40000 ALTER TABLE `notificaciones_admin` DISABLE KEYS */;
/*!40000 ALTER TABLE `notificaciones_admin` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `promociones`
--

DROP TABLE IF EXISTS `promociones`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `promociones` (
  `id` int NOT NULL AUTO_INCREMENT,
  `titulo` varchar(150) NOT NULL,
  `descripcion` text,
  `imagen_url` varchar(255) DEFAULT NULL,
  `activo` tinyint(1) DEFAULT '1',
  `fecha_creacion` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `promociones`
--

LOCK TABLES `promociones` WRITE;
/*!40000 ALTER TABLE `promociones` DISABLE KEYS */;
INSERT INTO `promociones` VALUES (1,'2x1 en cortes clásicos','Válido los lunes de julio',NULL,1,'2026-07-06 15:56:44');
/*!40000 ALTER TABLE `promociones` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `resenas`
--

DROP TABLE IF EXISTS `resenas`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `resenas` (
  `id` int NOT NULL AUTO_INCREMENT,
  `reserva_id` int NOT NULL,
  `usuario_id` int NOT NULL,
  `calificacion` tinyint NOT NULL,
  `comentario` text,
  `fecha_creacion` datetime DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_reserva` (`reserva_id`),
  KEY `usuario_id` (`usuario_id`),
  CONSTRAINT `resenas_ibfk_1` FOREIGN KEY (`reserva_id`) REFERENCES `reservas` (`id`) ON DELETE CASCADE,
  CONSTRAINT `resenas_ibfk_2` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`id`) ON DELETE CASCADE,
  CONSTRAINT `chk_calificacion` CHECK ((`calificacion` between 1 and 5))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `resenas`
--

LOCK TABLES `resenas` WRITE;
/*!40000 ALTER TABLE `resenas` DISABLE KEYS */;
/*!40000 ALTER TABLE `resenas` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `reserva_servicios_adicionales`
--

DROP TABLE IF EXISTS `reserva_servicios_adicionales`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `reserva_servicios_adicionales` (
  `id` int NOT NULL AUTO_INCREMENT,
  `reserva_id` int NOT NULL,
  `servicio_id` int NOT NULL,
  PRIMARY KEY (`id`),
  KEY `reserva_id` (`reserva_id`),
  KEY `servicio_id` (`servicio_id`),
  CONSTRAINT `reserva_servicios_adicionales_ibfk_1` FOREIGN KEY (`reserva_id`) REFERENCES `reservas` (`id`) ON DELETE CASCADE,
  CONSTRAINT `reserva_servicios_adicionales_ibfk_2` FOREIGN KEY (`servicio_id`) REFERENCES `servicios` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `reserva_servicios_adicionales`
--

LOCK TABLES `reserva_servicios_adicionales` WRITE;
/*!40000 ALTER TABLE `reserva_servicios_adicionales` DISABLE KEYS */;
/*!40000 ALTER TABLE `reserva_servicios_adicionales` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `reservas`
--

DROP TABLE IF EXISTS `reservas`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `reservas` (
  `id` int NOT NULL AUTO_INCREMENT,
  `usuario_id` int NOT NULL,
  `servicio_id` int NOT NULL,
  `horario_id` int DEFAULT NULL,
  `estado` enum('pendiente','confirmada','cancelada','completada') NOT NULL DEFAULT 'pendiente',
  `fecha_reserva` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `dia` date DEFAULT NULL,
  `hora_inicio` time DEFAULT NULL,
  `hora_fin` time DEFAULT NULL,
  `notificado_recordatorio` tinyint(1) DEFAULT '0',
  `estilo_referencia_nombre` varchar(150) DEFAULT NULL,
  `estilo_referencia_foto` varchar(500) DEFAULT NULL,
  `motivo_cancelacion` varchar(255) DEFAULT NULL,
  `cancelado_por` varchar(20) DEFAULT NULL,
  `oculto_admin` tinyint(1) NOT NULL DEFAULT '0',
  `fecha_cambio_estado` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `usuario_id` (`usuario_id`),
  KEY `servicio_id` (`servicio_id`),
  KEY `horario_id` (`horario_id`),
  CONSTRAINT `reservas_ibfk_1` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`id`) ON DELETE CASCADE,
  CONSTRAINT `reservas_ibfk_2` FOREIGN KEY (`servicio_id`) REFERENCES `servicios` (`id`) ON DELETE CASCADE,
  CONSTRAINT `reservas_ibfk_3` FOREIGN KEY (`horario_id`) REFERENCES `horarios_disponibles` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=16 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `reservas`
--

LOCK TABLES `reservas` WRITE;
/*!40000 ALTER TABLE `reservas` DISABLE KEYS */;
/*!40000 ALTER TABLE `reservas` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `servicios`
--

DROP TABLE IF EXISTS `servicios`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `servicios` (
  `id` int NOT NULL AUTO_INCREMENT,
  `nombre` varchar(150) NOT NULL,
  `descripcion` text,
  `precio` decimal(10,2) NOT NULL,
  `duracion_minutos` int NOT NULL,
  `imagen_url` varchar(255) DEFAULT NULL,
  `activo` tinyint(1) DEFAULT '1',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=9 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `servicios`
--

LOCK TABLES `servicios` WRITE;
/*!40000 ALTER TABLE `servicios` DISABLE KEYS */;
INSERT INTO `servicios` VALUES (1,'Corte Niño','Corte par aniño atencion especial para niño',30000.00,30,NULL,1),(2,'Corte Hombre','corte hombre luxury sin freestyle',30000.00,30,'https://res.cloudinary.com/sla80nsi/image/upload/v1783967268/jsyihv2exmbu45rf0i6p.jpg',1),(3,'Corte Barba y Cejas','Corte con diseño personalizado',40000.00,45,NULL,0),(4,'Cejas','perfilamiento de cejas',7000.00,10,'https://res.cloudinary.com/sla80nsi/image/upload/v1784042941/dtrueilw4czwuvzljknx.jpg',1),(5,'Barba','Perfilacion o afeitado',15000.00,20,'https://res.cloudinary.com/sla80nsi/image/upload/v1784042926/fx7h5vp9wycjw7qt2ikt.jpg',1),(6,'Corte con cejas','corte de cabello y cejas',30000.00,40,'https://res.cloudinary.com/sla80nsi/image/upload/v1784043077/pktgm73ynll8dm8f6hia.jpg',1),(7,'Limpieza facial','uso exclusivo del Vaporzono para la cara y regular los poros con mascarillas para puntos negros, mascarilla para ojeras, exfoliacionr y mascara LED',40000.00,40,'https://res.cloudinary.com/sla80nsi/image/upload/v1783966690/i78sg1gmyz5xhqqt8urd.jpg',1),(8,'Masaje Muscularrrrr','macarilla',20000.00,20,'https://res.cloudinary.com/sla80nsi/image/upload/v1783997311/kksotrpf9xtypdxrmcqg.jpg',1);
/*!40000 ALTER TABLE `servicios` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `usuarios`
--

DROP TABLE IF EXISTS `usuarios`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `usuarios` (
  `id` int NOT NULL AUTO_INCREMENT,
  `nombre` varchar(100) NOT NULL,
  `email` varchar(150) NOT NULL,
  `password` varchar(255) DEFAULT NULL,
  `telefono` varchar(20) NOT NULL,
  `rol` enum('admin','cliente','barbero') NOT NULL DEFAULT 'cliente',
  `fecha_creacion` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `es_golden_member` tinyint(1) NOT NULL DEFAULT '0',
  `cortes_completados` int NOT NULL DEFAULT '0',
  `fecha_ultimo_corte` date DEFAULT NULL,
  `foto_url` varchar(500) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `email` (`email`),
  UNIQUE KEY `telefono` (`telefono`),
  UNIQUE KEY `telefono_2` (`telefono`)
) ENGINE=InnoDB AUTO_INCREMENT=9 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `usuarios`
--

LOCK TABLES `usuarios` WRITE;
/*!40000 ALTER TABLE `usuarios` DISABLE KEYS */;
INSERT INTO `usuarios` VALUES (1,'Barbero Admin','dilan@gmail.com','$2b$12$QSErjF6fldQz.W5W1XqHqedhSHNGjpIvkhiBRSgyah7ZSBho8TgVW','3000000000','admin','2026-07-06 15:56:44',0,0,NULL,NULL);
/*!40000 ALTER TABLE `usuarios` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-07-14 12:19:29
