package org.eclipse.mita.base.typesystem

import com.google.inject.Inject
import java.util.regex.Pattern
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.types.NativeType
import org.eclipse.mita.base.types.TypesPackage
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.AtomicType
import org.eclipse.mita.base.typesystem.types.IntegerType
import org.eclipse.mita.base.typesystem.types.Signedness
import org.eclipse.xtext.naming.QualifiedName
import org.eclipse.xtext.scoping.IScopeProvider

class StdlibTypeRegistry {
	public static val voidTypeQID = QualifiedName.create(#["stdlib", "void"]);
	public static val integerTypeQIDs = #['xint8', 'int8', 'uint8', 'int16', 'xint16', 'uint16', 'xint32', 'int32', 'uint32'].map[QualifiedName.create(#["stdlib", it])];
	
	@Inject IScopeProvider scopeProvider;
	
	public def getVoidType(EObject context) {
		val voidScope = scopeProvider.getScope(context, TypesPackage.eINSTANCE.presentTypeSpecifier_Type);
		val voidType = voidScope.getSingleElement(StdlibTypeRegistry.voidTypeQID).EObjectOrProxy;
		return new AtomicType(voidType, "void");
	}
	
	public def getIntegerTypes(EObject context) {
		val typesScope = scopeProvider.getScope(context, TypesPackage.eINSTANCE.presentTypeSpecifier_Type);
		return StdlibTypeRegistry.integerTypeQIDs
			.map[typesScope.getSingleElement(it).EObjectOrProxy]
			.filter(NativeType)
			.map[translateNativeType(it)]
	}
	
	public def AbstractType translateNativeType(NativeType type) {
		val intPatternMatcher = Pattern.compile("(xint|int|uint)(\\d+)$").matcher(type?.name ?: "");
		if(intPatternMatcher.matches) {
			val signed = intPatternMatcher.group(1) == 'int';
			val unsigned = intPatternMatcher.group(1) == 'uint';
			val size = Integer.parseInt(intPatternMatcher.group(2)) / 8;
			
			new IntegerType(type, size, if(signed) Signedness.Signed else if(unsigned) Signedness.Unsigned else Signedness.DontCare);
		} else {
			new AtomicType(type, type.name);
		}
	}
}
