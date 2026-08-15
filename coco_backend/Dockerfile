# 1. 자바 17 환경을 가져옵니다.
FROM eclipse-temurin:17-jdk-alpine

# 2. 작업할 폴더를 지정하고 프로젝트 파일을 모두 복사합니다.
WORKDIR /app
COPY . .

# 3. 그래들(Gradle)로 프로젝트를 빌드합니다. (테스트는 생략해서 빠르게)
RUN chmod +x ./gradlew
RUN ./gradlew bootJar -x test

# 4. 빌드된 자바 실행 파일(.jar)을 실행합니다.
ENTRYPOINT ["sh", "-c", "java -jar build/libs/*.jar"]