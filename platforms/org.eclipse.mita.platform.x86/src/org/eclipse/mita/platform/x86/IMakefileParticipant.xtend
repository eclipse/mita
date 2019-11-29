package org.eclipse.mita.platform.x86

interface IMakefileParticipant {
	def Iterable<String> getLibraries();
}