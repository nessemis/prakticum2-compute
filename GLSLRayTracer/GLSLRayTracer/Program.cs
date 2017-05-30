namespace GLSLRayTracer
{
    class Program
    {
        static void Main(string[] args)
        {
            using (Window window = new Window())
            {
                window.Run(60.0);
            }
        }
    }
}
