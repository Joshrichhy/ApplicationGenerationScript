#!/bin/bash

# Prompt for the application name
echo "Enter the name of your Spring Boot application:"
read APP_NAME

# Set the package name
PACKAGE_NAME="com.example.$APP_NAME"

# Create the directory structure
mkdir -p $APP_NAME/.github/workflows
cat <<EOL > $APP_NAME/.github/workflows/build-create-docker-image.yml
name: Java CI with Maven

on:
  push:
    branches: [ "main" ]

jobs:
  test:
    name: Unit Test
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v1
      - name: Set up JDK 18
        uses: actions/setup-java@v1
        with:
          java-version: 18
      - name: Maven Package
        run: mvn -B clean package -DskipTests
      - name: Maven Verify
        run: mvn -B clean verify

  build:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3
      - name: Set up JDK 18
        uses: actions/setup-java@v3
        with:
          java-version: '18'
          distribution: 'temurin'
          cache: maven
      - name: Build with Maven
        run: mvn -B package --file pom.xml

      - name: Set up Node.js
        uses: actions/setup-node@v2
        with:
          node-version: '14'
        
      - name: Build, tag image
        id: build-image
        run: |
          docker build -t joshrichhy\\${APP_NAME}:latest .

EOL

mkdir -p $APP_NAME/src/main/java/$PACKAGE_NAME
mkdir -p $APP_NAME/src/main/resources
mkdir -p $APP_NAME/src/test/java/$PACKAGE_NAME


# Create the Spring Boot application file
touch $APP_NAME/src/main/java/$PACKAGE_NAME/${APP_NAME}Application.java

# Add the Spring Boot application code
echo "package $PACKAGE_NAME;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class ${APP_NAME}Application {

	public static void main(String[] args) {
		SpringApplication.run(${APP_NAME}Application.class, args);
	}
}" >> $APP_NAME/src/main/java/$PACKAGE_NAME/${APP_NAME}Application.java

# Create the application.properties file
touch $APP_NAME/src/main/resources/application.yml
echo "spring:
  profiles:
    active: \${SPRING_PROFILES_ACTIVE:local}

logging:
  level:
    org.springframework.security: DEBUG
" >> $APP_NAME/src/main/resources/application.yml



cat <<EOL > $APP_NAME/src/main/resources/application-local.yml
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/
    username: postgres
    password: postgres
    driver-class-name: org.postgresql.Driver
  jpa:
    hibernate:
      ddl-auto: update
    database: postgresql
    properties:
      hibernate:
        dialect: org.hibernate.dialect.PostgreSQLDialect
    open-in-view: false

  security:
    oauth2:
      resourceserver:
        jwt:
          issuer-uri: \${keycloak.server}/realms/\${keycloak.realm}

MAIL_HOST: \${EMAIL_HOST:sandbox.smtp.mailtrap.io}
MAIL_PORT: \${EMAIL_PORT:2525}
MAIL_USERNAME: \${EMAIL_USERNAME}
MAIL_PASSWORD: \${EMAIL_PASSWORD}
MAIL_SENDER: \${EMAIL_SENDER}

FRONTEND_URL: \${FRONTEND_BASE_URL:https://localhost:3000}

keycloak:
  server: http://localhost:8090
  username: admin
  password: admin
  realm:
  client:
  principal_attribute: preferred_username
  enabled:
jwt:
  secret: \${JWT_SECRET}
  expiration: \${JWT_EXPIRATION:3600}

logging:
  level:
    org.springframework.security: DEBUG

springdoc:
  swagger-ui:
    path: '/swagger-ui.html'
    filter: true
    tags-sorter: alpha
EOL

# Verify the file creation
if [ -f "$APP_NAME/src/main/resources/application-local.yml" ]; then
  echo "application-local.yml has been created successfully."
else
  echo "Failed to create application-local.yml."
fi

touch $APP_NAME/src/main/resources/application-dev.yml
touch $APP_NAME/src/main/resources/application-uat.yml
touch $APP_NAME/src/main/resources/application-prod.yml

# Create the test file
touch $APP_NAME/src/test/java/$PACKAGE_NAME/${APP_NAME}ApplicationTests.java

# Add the test code
echo "package $PACKAGE_NAME;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;

@SpringBootTest
public class ${APP_NAME}ApplicationTests {

	@Test
	public void contextLoads() {
	}

}" >> $APP_NAME/src/test/java/$PACKAGE_NAME/${APP_NAME}ApplicationTests.java


# Create Dockerfile
touch $APP_NAME/Dockerfile
echo "
FROM maven:3.8.7 as build
COPY . .
RUN mvn -B clean package -DskipTests

FROM openjdk:17
COPY --from=build ./target/*.jar app.jar
ENTRYPOINT [\"java\", \"-jar\", \"-Dserver.port=\${PORT}\", \"-Dspring.profiles.active=\${PROFILE}\",\"app.jar\"]
" >> $APP_NAME/Dockerfile

touch $APP_NAME/docker-compose.yml
echo "version: '3.18'

services:

  db:
    image: postgres:alpine
    restart: always
    ports:
      - "5431:5432"
    environment:
      POSTGRES_PASSWORD: postgres
      POSTGRES_USERNAME: postgres

  keycloak:
    image: quay.io/keycloak/keycloak:latest
    command: [ 'start-dev' ]
    ports:
      - "8090:8080"
    environment:
      KEYCLOAK_ADMIN: admin
      KEYCLOAK_ADMIN_PASSWORD: admin


  rabbitmq:
    image: rabbitmq:3.11-management-alpine
    ports:
      - "5672:5672"
      - "15672:15672"
    environment:
      RABBITMQ_DEFAULT_USER: guest
      RABBITMQ_DEFAULT_PASS: guest
      RABBITMQ_DEFAULT_VHOST: /
    volumes:
      - ./rabbitmq-data:/var/lib/rabbitmq

networks:
  local:
    name: local
    driver: bridge
  rabbitmq:
    name: rabbitmq
    driver: bridge" >> $APP_NAME/docker-compose.yml


# Create the pom.xml file (if you're using Maven)
touch $APP_NAME/pom.xml

# Add the Maven configuration
echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<project xmlns=\"http://maven.apache.org/POM/4.0.0\"
         xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\"
         xsi:schemaLocation=\"http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd\">
         
         <modelVersion>4.0.0</modelVersion>

	<groupId>$PACKAGE_NAME</groupId>
	<artifactId>$APP_NAME</artifactId>
	<version>0.0.1-SNAPSHOT</version>
	<packaging>jar</packaging>

	<name>$APP_NAME</name>
	<description>Demo project for Spring Boot</description>

	<parent>
		<groupId>org.springframework.boot</groupId>
		<artifactId>spring-boot-starter-parent</artifactId>
		<version>3.0.0</version>
		<relativePath/> <!-- lookup parent from repository -->
	</parent>

	<properties>
		<project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
		<project.reporting.outputEncoding>UTF-8</project.reporting.outputEncoding>
	</properties>

	<dependencies>
		<dependency>
			<groupId>org.springframework.boot</groupId>
			<artifactId>spring-boot-starter-web</artifactId>
		</dependency>

		<dependency>
			<groupId>org.springframework.boot</groupId>
			<artifactId>spring-boot-starter-test</artifactId>
			<scope>test</scope>
		</dependency>
		
		<dependency>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-starter-data-jpa</artifactId>
                <version>3.0.0</version>
            </dependency>

            <dependency>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-starter-validation</artifactId>
                <version>3.0.0</version>
            </dependency>

            <dependency>
                <groupId>org.postgresql</groupId>
                <artifactId>postgresql</artifactId>
                <version>42.6.0</version>
            </dependency>
            
            <dependency>
                <groupId>org.modelmapper</groupId>
                <artifactId>modelmapper</artifactId>
                <version>3.1.1</version>
            </dependency>
            
            <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-actuator</artifactId>
        </dependency>

        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-security</artifactId>
        </dependency>

	</dependencies>

	<build>
		<plugins>
			<plugin>
				<groupId>org.springframework.boot</groupId>
				<artifactId>spring-boot-maven-plugin</artifactId>
			</plugin>
		</plugins>
	</build>

</project>" >> $APP_NAME/pom.xml

# Change into the application directory
cd $APP_NAME

# Initialize a Git repository
git init

# Create Git Repo
gh repo create $APP_NAME --public

# Add all files to the repository
git add .

# Commit the changes
git commit -m "Initial commit"

git add README.md

git branch -M main
git remote add origin https://github.com/Joshrichhy/$APP_NAME.git
git push -u origin main

# Give file permission
chmod +x .

