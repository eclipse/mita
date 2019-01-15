package org.eclipse.mita.base.typesystem.infra;

public enum CachedBoolean {
	Uncached, True, False;
	
	public static CachedBoolean from(boolean b) {
		if(b) {
			return True;
		}
		return False;
	}
	
	/**
	 * WARNING CHECK FOR CACHED FIRST!
	 * @return
	 */
	public boolean get() {
		return this == True;
	}
}