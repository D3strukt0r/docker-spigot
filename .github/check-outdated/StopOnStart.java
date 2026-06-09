import org.bukkit.plugin.java.JavaPlugin;

/**
 * Throwaway plugin used only by the check-outdated workflow: as soon as the
 * server finishes starting (onEnable), it cleanly shuts it back down. This lets
 * the Docker check run the image through its real entrypoint (which forces
 * EULA=true, so the server boots fully) without leaving a server running or
 * relying on a forced kill.
 */
public final class StopOnStart extends JavaPlugin {
    @Override
    public void onEnable() {
        getLogger().info("StopOnStart: server started, shutting down");
        getServer().shutdown();
    }
}
