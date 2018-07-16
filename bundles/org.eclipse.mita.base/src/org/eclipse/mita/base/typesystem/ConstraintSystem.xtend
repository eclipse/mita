package org.eclipse.mita.base.typesystem

import com.google.inject.Inject
import com.google.inject.Provider
import java.util.ArrayList
import java.util.List
import org.eclipse.mita.base.typesystem.constraints.AbstractTypeConstraint

class ConstraintSystem {
	protected List<AbstractTypeConstraint> constraints = new ArrayList;
	protected final SymbolTable symbolTable;
	protected final TypeTable typeTable;
	
	@Inject
	protected Provider<SymbolTable> symbolTableProvider;
	@Inject
	protected Provider<TypeTable> typeTableProvider;
	
	new() {
		this.symbolTable = symbolTableProvider.get();
		this.typeTable = typeTableProvider.get();
	}
	
	def addConstraint(AbstractTypeConstraint constraint) {
		this.constraints.add(constraint);
	}
	
	def getSymbolTable() {
		return symbolTable;
	}
	
	def getTypeTable() {
		return typeTable;
	}
	
	override toString() {
		val res = new StringBuilder()
		
		res.append("Symbols:\n")
		res.append(symbolTable)
		res.append("\n\n")
		
		res.append("TypeTable:\n")
		res.append(typeTable)
		res.append("\n\n")
		
		res.append("Constraints:\n")
		constraints.forEach[
			res.append("\t")
			res.append(it)
			res.append("\n")
		]
		
		return res.toString
	}
	
}