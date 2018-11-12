/********************************************************************************
 * Copyright (c) 2017, 2018 TypeFox GmbH.
 *
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0.
 *
 * Contributors:
 *    TypeFox GmbH - initial contribution
 *
 * SPDX-License-Identifier: EPL-2.0
 ********************************************************************************/

pipeline {
    agent any
    
    tools { 
        maven 'apache-maven-latest' 
        jdk 'jdk1.8.0-latest' 
    }

    stages {
        stage("build") {
            steps {
                checkout scm;
                sh "mvn -Pplugins -Pplatforms -P!tests -P!deployment -P!sign -f bundles/pom.xml clean install"
            }
        }

//        stage('base tests') {
//            steps {
//                wrap([$class:'Xvnc', useXauthority: true]) {
//                    sh "mvn -P!plugins -P!platforms -Ptests -P!deployment -P!sign -f bundles/pom.xml install"
//                }
//            }
//            post {
//				success {
//					junit 'bundles/**/target/surefire-reports/TEST-*.xml' 
//				}
//			}
//        }

        stage("deploy") {
            steps {
                sh "mvn -P!plugins -P!platforms -P!tests -Pdeployment -Psign -f bundles/pom.xml install"
            }
            post {
                always {
                    archiveArtifacts artifacts: 'bundles/org.eclipse.mita.repository/target/*,bundles/org.eclipse.mita.cli/target/*-cli.jar', fingerprint: true
                }
            }
        }
    }
}
