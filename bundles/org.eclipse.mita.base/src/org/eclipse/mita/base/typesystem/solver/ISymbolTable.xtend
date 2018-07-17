package org.eclipse.mita.base.typesystem.solver

import org.eclipse.emf.ecore.EObject
import org.eclipse.xtext.naming.QualifiedName

interface ISymbolTable {
	public def EObject get(QualifiedName qn);
	
}