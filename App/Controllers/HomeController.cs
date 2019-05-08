using System.Diagnostics;
using KubernetesDemo.Models;
using KubernetesDemo.Services;
using Microsoft.AspNetCore.Mvc;

namespace KubernetesDemo.Controllers
{
    public class HomeController : Controller
    {
        private readonly BlogService _blogService;

        public HomeController(BlogService blogService)
        {
            _blogService = blogService;
        }

        public IActionResult Index()
        {
            var blogs = _blogService.GetBlogs();
            return View(blogs);
        }

        public IActionResult About()
        {
            ViewData["Message"] = "Your application description page.";

            return View();
        }

        public IActionResult Post()
        {
            return View();
        }

        public IActionResult Contact()
        {
            ViewData["Message"] = "Your contact page.";

            return View();
        }

        public IActionResult Error()
        {
            return View(new ErrorViewModel { RequestId = Activity.Current?.Id ?? HttpContext.TraceIdentifier });
        }
    }
}