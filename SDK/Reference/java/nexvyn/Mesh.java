package nexvyn;

/** A 3D mesh from G3d.mesh(), G3d.load() or G3d.custom(); it lives until free() or until the window closes. */
public final class Mesh {
    final int id;

    Mesh(int id) {
        this.id = id;
    }

    public void setColor(Object color) {
        G3d.setColor(this, color);
    }

    public void flat(boolean flat) {
        G3d.flat(this, flat);
    }

    public int triangles() {
        return G3d.triangles(this);
    }

    public boolean setTexture(String path) {
        return G3d.setTexture(this, path);
    }

    public String texture() {
        return G3d.texture(this);
    }

    public void free() {
        G3d.free(this);
    }

    @Override
    public String toString() {
        return "<mesh " + id + ">";
    }
}
